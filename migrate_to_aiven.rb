#!/usr/bin/env ruby
# Safe migration script - checks if data already exists before copying
require 'pg'

source_url = ENV['RENDER_DATABASE_URL'] || ENV['DATABASE_URL']
target_url = ENV['AIVEN_DATABASE_URL']

unless target_url
  puts "ERROR: AIVEN_DATABASE_URL not set"
  exit 1
end

puts "Source (Render): #{source_url.gsub(/:\/\/.*:.*@/, '://***:***@')}"
puts "Target (Aiven):  #{target_url.gsub(/:\/\/.*:.*@/, '://***:***@')}"
puts

src = PG.connect(source_url)
tgt = PG.connect(target_url)
skip_tables = %w[schema_migrations ar_internal_metadata]

# Check if target already has data
sample_table = src.exec("SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename NOT IN ('#{skip_tables.join("','")}') ORDER BY tablename LIMIT 1")
if sample_table.any?
  table_name = sample_table.first['tablename']
  target_count = tgt.exec("SELECT COUNT(*) FROM #{table_name}").first['count'].to_i
  source_count = src.exec("SELECT COUNT(*) FROM #{table_name}").first['count'].to_i

  if target_count == source_count && target_count > 0
    puts "Data already migrated to Aiven (both have #{target_count} rows in #{table_name}). Skipping."
    src.close
    tgt.close
    exit 0
  end
end

tgt.exec("SET session_replication_role = 'replica';")

tables_result = src.exec("SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename NOT IN ('#{skip_tables.join("','")}') ORDER BY tablename")
tables = tables_result.map { |r| r['tablename'] }

puts "Found #{tables.size} tables: #{tables.join(', ')}"
puts

tables.each do |table|
  count_result = src.exec("SELECT COUNT(*) FROM #{table}")
  count = count_result.first['count'].to_i

  cols_result = src.exec("SELECT column_name FROM information_schema.columns WHERE table_name = '#{table}' ORDER BY ordinal_position")
  columns = cols_result.map { |r| r['column_name'] }

  next if columns.empty?

  puts "Copying #{table}: #{count} rows"

  tgt.exec("TRUNCATE TABLE \"#{table}\" CASCADE;")

  if count > 0
    rows = src.exec("SELECT * FROM #{table}")
    rows.each do |row|
      col_names = columns.map { |c| "\"#{c}\"" }.join(', ')
      placeholders = columns.map.with_index { |_, i| "$#{i + 1}" }.join(', ')
      values = columns.map { |c| row[c] }
      tgt.exec_params("INSERT INTO \"#{table}\" (#{col_names}) VALUES (#{placeholders})", values)
    end
  end
  puts "  Done."
end

tgt.exec("SET session_replication_role = 'DEFAULT';")

puts "Copying schema_migrations..."
src_migrations = src.exec("SELECT * FROM schema_migrations")
src_migrations.each do |row|
  tgt.exec_params("INSERT INTO schema_migrations (version) VALUES ($1) ON CONFLICT (version) DO NOTHING", [row['version']])
end

puts "\nDone! #{tables.size} tables copied to Aiven."
src.close
tgt.close
