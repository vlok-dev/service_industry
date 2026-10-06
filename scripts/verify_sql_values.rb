#!/usr/bin/env ruby
# Second-pass verification: proves every *value* survives the SQL round trip, not
# just that the row counts match. Loads the dump into a throwaway schema inside a
# transaction, then compares a checksum of every column of every table against
# live, and rolls back.
#
#   bundle exec ruby scripts/verify_sql_values.rb
require "pg"
require "dotenv"

Dotenv.load(".env")

DIR = File.join(__dir__, "..", "db", "supabase_dump")
VERIFY_SCHEMA = "supabase_dump_verify"

conn = PG.connect(ENV["RENDER_DATABASE_URL"].to_s.strip.empty? ? ENV.fetch("AIVEN_DATABASE_URL") : ENV["RENDER_DATABASE_URL"])
conn.exec(%(DROP SCHEMA IF EXISTS #{VERIFY_SCHEMA} CASCADE))
conn.exec("BEGIN")
conn.exec("CREATE SCHEMA #{VERIFY_SCHEMA}")
conn.exec("SET LOCAL search_path = #{VERIFY_SCHEMA}")

Dir.glob(File.join(DIR, "*.sql")).reject { |f| File.basename(f) == "all_in_one.sql" }.sort_by { |f| File.basename(f) }.each do |path|
  sql = File.read(path, encoding: "UTF-8")
  sql = sql.lines.reject { |l| %w[BEGIN; COMMIT;].include?(l.strip) }.join
  conn.exec(sql)
end

tables = conn.exec(<<~SQL).to_a.map { |r| r["tablename"] }
  SELECT tablename FROM pg_tables
  WHERE schemaname = '#{VERIFY_SCHEMA}' AND tablename NOT IN ('schema_migrations', 'ar_internal_metadata')
  ORDER BY tablename
SQL

# md5 over every column of every row, NULL distinguished from empty string.
def checksum(conn, schema, table)
  cols = conn.exec(<<~SQL).to_a.map { |r| r["column_name"] }
    SELECT a.attname AS column_name
    FROM pg_attribute a
    JOIN pg_class c ON c.oid = a.attrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = '#{schema}' AND c.relname = '#{table}'
      AND a.attnum > 0 AND NOT a.attisdropped
    ORDER BY a.attnum
  SQL
  expr = cols.map { |c| %(coalesce("#{c}"::text, '\\N')) }.join(" || '|' || ")
  conn.exec(%(SELECT COALESCE(md5(string_agg(#{expr}, '' ORDER BY id)), 'empty') AS md5 FROM "#{schema}"."#{table}")).first["md5"]
end

puts format("  %-32s %-34s %s", "table", "live md5", "match")
puts "  " + "-" * 80

failures = []
tables.each do |table|
  live = checksum(conn, "public", table)
  loaded = checksum(conn, VERIFY_SCHEMA, table)
  ok = live == loaded
  failures << table unless ok
  puts format("  %-32s %-34s %s", table, live[0, 32], ok ? "ok" : "MISMATCH")
end

begin
  puts "\nvalue-level check: #{failures.empty? ? 'ALL TABLES IDENTICAL' : "FAILED: #{failures.inspect}"}"
  puts "checked tables: #{tables.size}"
ensure
  # Always roll back, even on failure or Ctrl-C. Postgres also rolls back on
  # disconnect, but doing it explicitly keeps the verify schema from lingering.
  conn.exec("ROLLBACK") rescue nil
  conn.exec(%(DROP SCHEMA IF EXISTS #{VERIFY_SCHEMA} CASCADE)) rescue nil
  puts "rolled back; verify schema present? #{conn.exec("SELECT COUNT(*) AS c FROM pg_namespace WHERE nspname='#{VERIFY_SCHEMA}'").first['c'].to_i}"
  conn.close rescue nil
end

exit(failures.empty? ? 0 : 1)
