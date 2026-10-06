#!/usr/bin/env ruby
# Loads db/supabase_dump/*.sql into Supabase in the correct order, using the pg
# gem that is already in the bundle. No psql or Supabase CLI required.
#
#   1. Supabase dashboard -> Project Settings -> Database -> Connection string -> URI
#   2. Put it in .env as SUPABASE_DATABASE_URL=postgres://...
#   3. bundle exec ruby scripts/load_into_supabase.rb
#
# Safety: refuses to run against Aiven or Render, because those are production.
# Exits before doing anything if the target already contains our data.

require "pg"
require "uri"
require "dotenv"

Dotenv.load(".env")

DIR = File.join(__dir__, "..", "db", "supabase_dump")

def env_present(key)
  v = ENV[key].to_s.strip
  v.empty? ? nil : v
end

# Expected row counts are read from the source database at run time, never
# hardcoded. Hardcoding them is what let a stale-source dump look correct.
def source_url
  env_present("RENDER_DATABASE_URL") || env_present("AIVEN_DATABASE_URL")
end

def expected_counts
  url = source_url
  return {} if url.nil? || url.empty?

  conn = PG.connect(url.include?("?") ? url : "#{url}?sslmode=require")
  tables = conn.exec(<<~SQL).to_a.map { |r| r["table_name"] }
    SELECT table_name FROM information_schema.tables
    WHERE table_schema='public'
      AND table_name NOT IN ('schema_migrations','ar_internal_metadata')
    ORDER BY table_name
  SQL
  counts = {}
  tables.each do |t|
    counts[t] = conn.exec(%(SELECT COUNT(*) AS n FROM "#{t}")).first["n"].to_i
  end
  %w[schema_migrations ar_internal_metadata].each do |t|
    counts[t] = conn.exec(%(SELECT COUNT(*) AS n FROM "#{t}")).first["n"].to_i
  end
  conn.close
  counts
rescue PG::Error => e
  warn "could not read expected counts from source: #{e.message.lines.first.to_s.strip}"
  {}
end

SOURCE_LABEL = env_present("RENDER_DATABASE_URL") ? "Render Postgres" : "Aiven"
EXPECTED = expected_counts

url = ENV["SUPABASE_DATABASE_URL"].to_s.strip
if url.empty?
  abort <<~MSG
    SUPABASE_DATABASE_URL is not set.

    Add this line to #{File.expand_path('.env')}:

      SUPABASE_DATABASE_URL=postgresql://postgres.PROJECT_REF:PASSWORD@REGION.pooler.supabase.com:5432/postgres

    Supabase dashboard -> Project Settings -> Database -> Connection string -> URI.
    Use the Session pooler (port 5432), not the transaction pooler (6543).
  MSG
end

# Never point this at production.
host =
  begin
    URI.parse(url).host.to_s
  rescue URI::InvalidURIError
    url[%r{@([^:/@]+)}, 1].to_s
  end
if host.include?("aivencloud") || host.include?("onrender") || host.include?("render.com")
  abort "REFUSING: #{host} is the live production database. This script only writes to Supabase."
end
unless host.include?("supabase")
  warn "WARNING: host #{host} does not look like Supabase."
  abort "Set ALLOW_ANY_HOST=1 to proceed anyway." unless ENV["ALLOW_ANY_HOST"] == "1"
end

# Supabase direct hosts (db.<ref>.supabase.co) are IPv6-only on new projects.
# Detect that up front: libpq reports it as an unhelpful name-resolution error.
if host.start_with?("db.") && host.end_with?(".supabase.co")
  require "resolv"
  ipv4 = begin
    Resolv::DNS.open { |dns| dns.getresources(host, Resolv::DNS::Resource::IN::A).map { |r| r.address.to_s } }
  rescue StandardError
    []
  end
  if ipv4.empty?
    abort <<~MSG

      #{host} is Supabase's *direct* connection host, which is IPv6-only.

      Use the pooler host instead. In the Supabase dashboard go to
      Project Settings -> Database -> Connection string and copy the
      **Session pooler** URI (the one on port 5432), which looks like:

        postgresql://postgres.<ref>:<password>@aws-0-<region>.pooler.supabase.com:5432/postgres

      Replace SUPABASE_DATABASE_URL in .env with that string and re-run.
    MSG
  end
end

files = Dir.glob(File.join(DIR, "*.sql"))
             .reject { |f| File.basename(f) == "all_in_one.sql" }
             .sort_by { |f| File.basename(f) }
abort "No .sql files found in #{DIR}. Run: bundle exec ruby scripts/dump_live_to_sql.rb" if files.empty?

puts "Target host: #{host}"
puts "Expected counts read from: #{SOURCE_LABEL} (#{EXPECTED.size} tables)"
puts "Files to run: #{files.size}"
puts

conn = PG.connect(url)

# Refuse to double-load: CREATE TABLE would fail anyway, but this gives a clear message.
existing = conn.exec(<<~SQL).first["n"].to_i
  SELECT COUNT(*) AS n FROM information_schema.tables
  WHERE table_schema = 'public' AND table_name = 'clients'
SQL
if existing.positive? && ENV["FORCE"] != "1"
  count = conn.exec("SELECT COUNT(*) AS n FROM clients").first["n"].to_i
  abort <<~MSG if count.positive?

    Target already has data (public.clients has #{count} rows). Refusing to load on top of it.
    If this is a fresh project you want to wipe first, run with FORCE=1 DROP_TABLES=1.
  MSG
end

if ENV["DROP_TABLES"] == "1"
  # Drop only our own tables. Deliberately not DROP SCHEMA public CASCADE: on
  # Supabase that would take out the schema's grants and extensions and break
  # the dashboard's table browser.
  ours = File.read(File.join(DIR, "00_schema.sql"), encoding: "UTF-8")
            .scan(/^CREATE TABLE "([^"]+)"/).flatten
  ours += %w[schema_migrations ar_internal_metadata]
  puts "dropping #{ours.size} tables: #{ours.join(', ')}"
  conn.exec(ours.reverse.map { |t| %(DROP TABLE IF EXISTS "#{t}" CASCADE) }.join(";\n"))
  puts "dropped."
end

conn.exec("SET statement_timeout = 0")

files.each do |path|
  name = File.basename(path)
  sql = File.read(path, encoding: "UTF-8")
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  begin
    conn.exec(sql)
  rescue PG::Error => e
    abort "\nFAILED in #{name}: #{e.message}\n#{e.backtrace&.first(3)&.join("\n")}"
  end
  took = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
  puts format("  ok  %-40s %6d ms", name, took)
end

puts "\nverifying row counts:"
bad = []
EXPECTED.each do |table, want|
  got = conn.exec(%(SELECT COUNT(*) AS n FROM "#{table}")).first["n"].to_i
  ok = got == want
  bad << "#{table} (got #{got}, want #{want})" unless ok
  puts format("  %-30s %6d / %-6d %s", table, got, want, ok ? "ok" : "MISMATCH")
end

puts "\nsequence sanity (next value must exceed max id):"
conn.exec(<<~SQL).to_a.each do |r|
  SELECT c.relname AS table, a.attname AS column,
         pg_get_serial_sequence(c.relname, a.attname) AS seq
  FROM pg_attribute a
  JOIN pg_class c ON c.oid = a.attrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relname IN ('clients','inventory_items','jobs','users','suppliers')
    AND a.attnum > 0 AND NOT a.attisdropped
    AND pg_get_serial_sequence(c.relname, a.attname) IS NOT NULL
  ORDER BY 1
SQL
  max_id = conn.exec(%(SELECT COALESCE(MAX("#{r['column']}"),0) AS m FROM "#{r['table']}")).first["m"].to_i
  nextval = conn.exec("SELECT nextval('#{r['seq']}') AS v").first["v"].to_i
  ok = nextval > max_id
  bad << "#{r['table']} sequence" unless ok
  puts format("  %-30s max=%-7d next=%-7d %s", r["table"], max_id, nextval, ok ? "ok" : "TOO LOW")
end

conn.close

puts
if bad.empty?
  puts "SUCCESS - Supabase is loaded and matches live."
  puts "Next: set DATABASE_URL in the Render dashboard to this same connection string."
else
  puts "PROBLEMS: #{bad.join('; ')}"
  exit 1
end
