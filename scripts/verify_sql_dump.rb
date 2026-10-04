#!/usr/bin/env ruby
# Proves the generated Supabase SQL actually runs, without touching production.
#
#   bundle exec ruby scripts/verify_sql_dump.rb
#
# Everything executes inside one transaction, in a throwaway schema, and is then
# rolled back. If this script crashes mid-way Postgres also rolls back, and the
# verify schema is dropped separately, so `public` is never modified.
require "pg"
require "dotenv"

Dotenv.load(".env")

DIR = File.join(__dir__, "..", "db", "supabase_dump")
VERIFY_SCHEMA = "supabase_dump_verify"

conn = PG.connect(ENV["RENDER_DATABASE_URL"].presence || ENV.fetch("AIVEN_DATABASE_URL"))
conn.exec(%(DROP SCHEMA IF EXISTS #{VERIFY_SCHEMA} CASCADE))

conn.exec("BEGIN")
conn.exec("CREATE SCHEMA #{VERIFY_SCHEMA}")
conn.exec("SET LOCAL search_path = #{VERIFY_SCHEMA}")

files = Dir.glob(File.join(DIR, "*.sql")).reject { |f| File.basename(f) == "all_in_one.sql" }.sort_by { |f| File.basename(f) }

files.each do |path|
  name = File.basename(path)
  sql = File.read(path, encoding: "UTF-8")
  # The dump wraps each file in its own transaction; we already have one open,
  # and a nested COMMIT would defeat the rollback, so strip them.
  sql = sql.lines.reject { |l| %w[BEGIN; COMMIT;].include?(l.strip) }.join
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  conn.exec(sql)
  took = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
  puts format("  ok  %-40s %6d ms", name, took)
end

puts "\nrow counts as loaded into #{VERIFY_SCHEMA}:"
puts format("  %-32s %8s %8s", "table", "live", "loaded")
puts "  " + "-" * 50

mismatches = []
conn.exec("SELECT tablename FROM pg_tables WHERE schemaname = '#{VERIFY_SCHEMA}' ORDER BY tablename").to_a.each do |t|
  table = t["tablename"]
  live = conn.exec(%(SELECT COUNT(*) AS c FROM public."#{table}")).first["c"].to_i
  loaded = conn.exec(%(SELECT COUNT(*) AS c FROM "#{table}")).first["c"].to_i
  mismatches << table if live != loaded
  puts format("  %-32s %8d %8d%s", table, live, loaded, live == loaded ? "" : "   <-- MISMATCH")
end

puts "\nsequence check (next value must exceed every existing id):"
bad_seq = []
conn.exec(<<~SQL).to_a.each do |r|
  SELECT c.relname AS table, a.attname AS column,
         pg_get_serial_sequence(c.relname, a.attname) AS seq
  FROM pg_attribute a
  JOIN pg_class c ON c.oid = a.attrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = '#{VERIFY_SCHEMA}' AND a.attnum > 0 AND NOT a.attisdropped
    AND pg_get_serial_sequence(c.relname, a.attname) IS NOT NULL
  ORDER BY 1
SQL
  table = r["table"]
  max_id = conn.exec(%(SELECT COALESCE(MAX("#{r['column']}"),0) AS m FROM "#{table}")).first["m"].to_i
  nextval = conn.exec("SELECT nextval('#{r['seq']}') AS v").first["v"].to_i
  status = nextval > max_id ? "ok" : "TOO LOW"
  bad_seq << table if nextval <= max_id
  puts format("  %-32s max=%-7d next=%-7d %s", table, max_id, nextval, status)
end

# Prove values survived the round trip rather than just counting rows.
puts "\nspot checks:"
samples = [
  ["clients", "SELECT name FROM clients ORDER BY id LIMIT 1"],
  ["inventory_items", "SELECT code, name FROM inventory_items ORDER BY id LIMIT 1"],
  ["users", "SELECT email FROM users ORDER BY id LIMIT 1"]
]
samples.each do |label, sql|
  puts "  #{label}: #{conn.exec(sql).first.values.join(' | ')[0, 90]}"
end

conn.exec("ROLLBACK")
conn.exec(%(DROP SCHEMA IF EXISTS #{VERIFY_SCHEMA} CASCADE))

live_tables = conn.exec("SELECT COUNT(*) AS c FROM pg_tables WHERE schemaname='public'").first["c"].to_i
puts "\nrolled back. tables now in public: #{live_tables} (expected 20 = 18 app + schema_migrations + ar_internal_metadata)"
puts "verify schema still present? #{conn.exec("SELECT COUNT(*) AS c FROM pg_namespace WHERE nspname='#{VERIFY_SCHEMA}'").first['c'].to_i}"

if mismatches.empty? && bad_seq.empty?
  puts "\nVERIFIED: all row counts match and every sequence is correctly positioned."
else
  puts "\nFAILED: mismatches=#{mismatches.inspect} bad_sequences=#{bad_seq.inspect}"
  exit 1
end

conn.close
