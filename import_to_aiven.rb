#!/usr/bin/env ruby
# Fast bulk import from Render Postgres to Aiven using COPY
# Usage: bundle exec ruby import_to_aiven.rb
require 'pg'

def csv_escape(value)
  return "" if value.nil?
  s = value.to_s
  if s.match?(/[",\n\r]/)
    '"' + s.gsub('"', '""') + '"'
  else
    s
  end
end

source_url = ENV['RENDER_DATABASE_URL']
aiven_url = ENV['AIVEN_DATABASE_URL'] || ENV['DATABASE_URL']

if aiven_url.nil? && File.exist?('.env')
  File.foreach('.env') do |line|
    aiven_url = $1.strip if line =~ /^AIVEN_DATABASE_URL=(.+)$/
    aiven_url ||= $1.strip if line =~ /^DATABASE_URL=(.+)$/
  end
end

unless source_url
  puts "ERROR: Set env var RENDER_DATABASE_URL"
  puts "In PowerShell: Set-Content env:RENDER_DATABASE_URL '<render-postgres-url>'"
  exit 1
end

unless aiven_url&.include?('aivencloud.com')
  puts "ERROR: No Aiven URL found in AIVEN_DATABASE_URL or .env"
  exit 1
end

puts "Connecting to source (Render)... "
src = PG.connect(source_url)
puts "  OK"

puts "Connecting to target (Aiven)... "
tgt = PG.connect(aiven_url)
puts "  OK"

skip_tables = %w[schema_migrations ar_internal_metadata]
tables = src.exec("SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename NOT IN ('#{skip_tables.join("','")}') ORDER BY tablename").map { |r| r['tablename'] }

puts "\nFound #{tables.size} tables: #{tables.join(', ')}"
puts ""

tables.each do |table|
  count = src.exec("SELECT COUNT(*) FROM #{table}").first['count'].to_i
  cols = src.exec("SELECT column_name FROM information_schema.columns WHERE table_name = '#{table}' ORDER BY ordinal_position").map { |r| r['column_name'] }

  puts "Copying #{table}: #{count} rows (#{cols.size} cols)"

  tgt.exec("TRUNCATE TABLE \"#{table}\" CASCADE;")

  if count > 0
    col_names = cols.map { |c| "\"#{c}\"" }.join(', ')
    tgt.copy_data("COPY #{table} (#{col_names}) FROM STDIN WITH (FORMAT csv)") do
      src.query("SELECT * FROM #{table}").each do |row|
        csv_line = cols.map { |c| csv_escape(row[c]) }.join(',')
        tgt.put_copy_data(csv_line + "\n")
      end
    end
    puts "  Copied #{count} rows"
  else
    puts "  Empty table"
  end
end

puts "Copying schema_migrations..."
src.exec("SELECT version FROM schema_migrations").each do |row|
  tgt.exec_params("INSERT INTO schema_migrations (version) VALUES ($1) ON CONFLICT (version) DO NOTHING", [row['version']])
end

puts "\nDone! #{tables.size} tables copied to Aiven."
src.close
tgt.close
