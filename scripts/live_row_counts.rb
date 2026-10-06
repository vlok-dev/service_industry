#!/usr/bin/env ruby
# Counts rows in every public table on the live Aiven database.
# Usage: bundle exec ruby scripts/live_row_counts.rb
require "pg"
require "dotenv"

Dotenv.load(".env")

url = ENV["AIVEN_DATABASE_URL"]
abort "AIVEN_DATABASE_URL not set" if url.nil? || url.empty?

conn = PG.connect(url)

tables = conn.exec(<<~SQL).map { |r| r["tablename"] }
  SELECT tablename
  FROM pg_tables
  WHERE schemaname = 'public'
    AND tablename NOT IN ('schema_migrations', 'ar_internal_metadata')
  ORDER BY tablename
SQL

total = 0
puts format("%-32s %10s", "table", "rows")
puts "-" * 43
tables.each do |table|
  count = conn.exec(%(SELECT COUNT(*) FROM "#{table}")).first["count"].to_i
  total += count
  puts format("%-32s %10d", table, count)
end
puts "-" * 43
puts format("%-32s %10d", "TOTAL", total)

conn.close
