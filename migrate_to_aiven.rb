#!/usr/bin/env ruby
require 'pg'

source_url = ENV['RENDER_DATABASE_URL'] || ENV['DATABASE_URL']
target_url = ENV['AIVEN_DATABASE_URL']

unless target_url
  puts "ERROR: AIVEN_DATABASE_URL environment variable not set"
  puts "Set it in Render Dashboard -> Environment -> Add Environment Variable"
  puts "Name: AIVEN_DATABASE_URL"
  puts "Value: postgres://avnadmin:AVNS_...@...aivencloud.com:16981/defaultdb?sslmode=require"
  exit 1
end

puts "Source (Render): #{source_url.gsub(/:\/\/.*:.*@/, '://***:***@')}"
puts "Target (Aiven):  #{target_url.gsub(/:\/\/.*:.*@/, '://***:***@')}"
puts

src = PG.connect(source_url)
tgt = PG.connect(target_url)
skip_tables = %w[schema_migrations ar_internal_metadata]

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
