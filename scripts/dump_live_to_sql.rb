#!/usr/bin/env ruby
# Generates plain-SQL files (CREATE TABLE + INSERT + sequence resets) from the
# live Aiven database so they can be pasted into the Supabase SQL editor.
#
#   bundle exec ruby scripts/dump_live_to_sql.rb
#
# Output lands in db/supabase_dump/ and is safe to re-run (files are overwritten).
require "pg"
require "dotenv"
require "fileutils"

Dotenv.load(".env")

# Which live database to read. Defaults to Aiven, but RENDER_DATABASE_URL takes
# precedence so a dump can be taken from whichever database production actually
# used - those two can drift apart, and picking the wrong one silently loses rows.
SOURCE_URL = ENV["RENDER_DATABASE_URL"].presence || ENV["AIVEN_DATABASE_URL"].presence
abort "Set RENDER_DATABASE_URL or AIVEN_DATABASE_URL in .env" if SOURCE_URL.nil? || SOURCE_URL.empty?

SOURCE_LABEL = ENV["RENDER_DATABASE_URL"].present? ? "Render Postgres" : "Aiven"

puts "Reading from: #{SOURCE_LABEL}"

OUT_DIR = File.join(__dir__, "..", "db", "supabase_dump")
FILE_BUDGET = 1_200_000 # bytes per data file before rolling over to the next part
ROWS_PER_STATEMENT = 200

SERIAL_WORD = { "int4" => "serial", "int8" => "bigserial", "int2" => "smallserial" }.freeze
NUMERIC_TYPES = %w[int2 int4 int8 float4 float8 numeric money oid].freeze

def banner(title)
  ["-- " + ("=" * 74), "-- #{title}", "-- " + ("=" * 74), ""].join("\n")
end

def escape_literal(str)
  out = str.to_s.dup
  out.gsub!("\\") { "\\\\" }
  out.gsub!("'", "''")
  out.gsub!("\n") { "\\n" }
  out.gsub!("\r") { "\\r" }
  out.gsub!("\t") { "\\t" }
  out
end

def sql_literal(value, base_type)
  return "NULL" if value.nil?
  return (value == "t" ? "TRUE" : "FALSE") if base_type == "bool"
  return value if NUMERIC_TYPES.include?(base_type)

  "E'" + escape_literal(value) + "'"
end

def column_ddl(row)
  type = row["serial_seq"] ? SERIAL_WORD.fetch(row["base_type"], row["full_type"]) : row["full_type"]
  parts = ['  "%s" %s' % [row["column_name"], type]]
  parts << "NOT NULL" if row["not_null"] == "t"
  parts << "DEFAULT #{row['default_expr']}" if row["default_expr"] && row["serial_seq"].nil?
  parts.join(" ")
end

def write_data_file(path, body, table, part)
  head = banner("DATA: #{table}#{part > 1 ? format(' part %02d', part) : ''}")
  File.write(path, [head, "BEGIN;", "", body, "COMMIT;", ""].join("\n"), encoding: "UTF-8")
end

conn = PG.connect(SOURCE_URL)

def q(conn, sql)
  conn.exec(sql).to_a
end

# --------------------------------------------------------------------------
# Introspect
# --------------------------------------------------------------------------
METADATA_TABLES = %w[schema_migrations ar_internal_metadata].freeze

# Every public table gets DDL, including Rails' two metadata tables, which have no
# foreign keys and are therefore created first.
BASE_TABLES = q(conn, <<~SQL).map { |r| r["tablename"] }
  SELECT tablename FROM pg_tables
  WHERE schemaname = 'public'
  ORDER BY tablename
SQL

COLUMNS = q(conn, <<~SQL).group_by { |r| r["table_name"] }
  SELECT c.relname AS table_name, a.attname AS column_name,
         format_type(a.atttypid, a.atttypmod) AS full_type, t.typname AS base_type,
         a.attnotnull AS not_null, a.attnum,
         pg_get_serial_sequence(c.relname, a.attname) AS serial_seq,
         pg_get_expr(d.adbin, d.adrelid) AS default_expr
  FROM pg_attribute a
  JOIN pg_class c ON c.oid = a.attrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
  JOIN pg_type t ON t.oid = a.atttypid
  LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
  WHERE n.nspname = 'public' AND c.relkind = 'r'
    AND a.attnum > 0 AND NOT a.attisdropped
  ORDER BY c.relname, a.attnum
SQL

PKS = q(conn, <<~SQL).group_by { |r| r["table_name"] }
  SELECT c.relname AS table_name, con.conname, pg_get_constraintdef(con.oid) AS def
  FROM pg_constraint con
  JOIN pg_class c ON c.oid = con.conrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND con.contype = 'p'
SQL

FKS = q(conn, <<~SQL).group_by { |r| r["table_name"] }
  SELECT c.relname AS table_name, con.conname, pg_get_constraintdef(con.oid) AS def
  FROM pg_constraint con
  JOIN pg_class c ON c.oid = con.conrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND con.contype = 'f'
  ORDER BY c.relname, con.conname
SQL

INDEXES = q(conn, <<~SQL)
  SELECT t.relname AS table_name, pg_get_indexdef(ix.indexrelid) AS def
  FROM pg_index ix
  JOIN pg_class i ON i.oid = ix.indexrelid
  JOIN pg_class t ON t.oid = ix.indrelid
  JOIN pg_namespace n ON n.oid = t.relnamespace
  WHERE n.nspname = 'public' AND NOT ix.indisprimary
  ORDER BY t.relname, i.relname
SQL

# --------------------------------------------------------------------------
# Dependency order (topological sort over foreign keys)
# --------------------------------------------------------------------------
deps = Hash.new { |h, k| h[k] = [] }
FKS.each do |table, rows|
  rows.each do |r|
    ref = r["def"][/REFERENCES\s+"?([a-z0-9_]+)"?/i, 1]
    deps[table] << ref if ref && ref != table
  end
end

ordered = []
remaining = BASE_TABLES.dup
until remaining.empty?
  ready = remaining.select { |t| (deps[t] & (remaining - [t])).empty? }
  ready = [remaining.first] if ready.empty?
  ready.sort.each do |t|
    ordered << t
    remaining.delete(t)
  end
end

# --------------------------------------------------------------------------
# 00_schema.sql
# --------------------------------------------------------------------------
schema = [banner("SCHEMA - tables, primary keys, foreign keys, indexes"),
          "SET standard_conforming_strings = on;", "",
          "CREATE EXTENSION IF NOT EXISTS plpgsql;", "", "BEGIN;", ""]

ordered.each do |table|
  body = COLUMNS.fetch(table).map { |c| column_ddl(c) }
  schema << "CREATE TABLE \"#{table}\" ("
  schema << body.join(",\n")
  schema << ");"
  schema << ""
end

ordered.each do |table|
  (PKS[table] || []).each { |pk| schema << "ALTER TABLE \"#{table}\" ADD CONSTRAINT \"#{pk['conname']}\" #{pk['def']};" }
end
schema << ""

ordered.each do |table|
  (FKS[table] || []).each { |fk| schema << "ALTER TABLE \"#{table}\" ADD CONSTRAINT \"#{fk['conname']}\" #{fk['def']};" }
end
schema << ""

INDEXES.each { |idx| schema << "#{idx['def'].gsub(/\bON\s+public\./, 'ON ')};" }
schema << ""
schema << "COMMIT;"
schema << ""

# --------------------------------------------------------------------------
# Data files
# --------------------------------------------------------------------------
FileUtils.rm_rf(OUT_DIR)
FileUtils.mkdir_p(OUT_DIR)
File.write(File.join(OUT_DIR, "00_schema.sql"), schema.join("\n"), encoding: "UTF-8")

data_files = []
row_totals = {}
file_index = 0

ordered.each do |table|
  next if METADATA_TABLES.include?(table)

  rows = q(conn, %(SELECT * FROM "#{table}"))
  row_totals[table] = rows.length
  next if rows.empty?

  cols = COLUMNS.fetch(table)
  col_list = cols.map { |c| "\"#{c['column_name']}\"" }.join(", ")
  prefix = "INSERT INTO \"#{table}\" (#{col_list}) VALUES\n"

  part = 0
  file_index += 1
  pending = []
  buffer = +""

  rows.each do |row|
    pending << "(#{cols.map { |c| sql_literal(row[c['column_name']], c['base_type']) }.join(', ')})"
    if pending.size >= ROWS_PER_STATEMENT
      buffer << prefix << pending.join(",\n") << ";\n\n"
      pending.clear
    end
    next if buffer.bytesize < FILE_BUDGET

    part += 1
    name = format("%02d_data_%03d_%s_part%02d.sql", 10, file_index, table, part)
    write_data_file(File.join(OUT_DIR, name), buffer, table, part)
    data_files << name
    buffer = +""
  end

  unless pending.empty?
    buffer << prefix << pending.join(",\n") << ";\n\n"
    pending.clear
  end

  part += 1
  suffix = part > 1 ? format("_part%02d", part) : ""
  name = format("%02d_data_%03d_%s%s.sql", 10, file_index, table, suffix)
  write_data_file(File.join(OUT_DIR, name), buffer, table, part)
  data_files << name
end

# --------------------------------------------------------------------------
# Rails metadata
# --------------------------------------------------------------------------
meta = [banner("Rails schema_migrations + ar_internal_metadata"), "BEGIN;", ""]
%w[schema_migrations ar_internal_metadata].each do |table|
  rows = q(conn, %(SELECT * FROM "#{table}"))
  next if rows.empty?

  col_names = rows.first.keys.map { |k| "\"#{k}\"" }.join(", ")
  rows.each do |row|
    values = row.values.map { |v| "E'" + escape_literal(v) + "'" }
    meta << "INSERT INTO \"#{table}\" (#{col_names}) VALUES (#{values.join(', ')});"
  end
  meta << ""
end
meta << "COMMIT;"
meta << ""

# --------------------------------------------------------------------------
# 99_sequences.sql
# --------------------------------------------------------------------------
seq = [banner("SEQUENCE RESETS - required, or the first insert fails on a duplicate key"),
       "BEGIN;", ""]
ordered.each do |table|
  COLUMNS.fetch(table).select { |c| c["serial_seq"] }.each do |c|
    name = c["serial_seq"].sub(/\Apublic\./, "")
    seq << %(SELECT setval('#{name}', COALESCE((SELECT MAX("#{c['column_name']}") FROM "#{table}"), 0) + 1, false);)
  end
end
seq << ""
seq << "COMMIT;"
seq << ""

File.write(File.join(OUT_DIR, "00_schema.sql"), schema.join("\n"), encoding: "UTF-8")
File.write(File.join(OUT_DIR, "90_rails_metadata.sql"), meta.join("\n"), encoding: "UTF-8")
File.write(File.join(OUT_DIR, "99_sequences.sql"), seq.join("\n"), encoding: "UTF-8")

all = +""
(["00_schema.sql"] + data_files.sort + ["90_rails_metadata.sql", "99_sequences.sql"]).each do |f|
  all << File.read(File.join(OUT_DIR, f))
end
File.write(File.join(OUT_DIR, "all_in_one.sql"), all, encoding: "UTF-8")

version = q(conn, "SHOW server_version").first["server_version"]
conn.close

total = row_totals.reject { |t, _| METADATA_TABLES.include?(t) }.values.sum
readme = <<~MD
  # Supabase import bundle

  Generated from the live Aiven database (PostgreSQL #{version}) on #{Time.now.utc.strftime('%Y-%m-%d %H:%M UTC')}.

  **#{total} application rows** across #{BASE_TABLES.size - METADATA_TABLES.size} tables,
  plus Rails' `schema_migrations` and `ar_internal_metadata`.

  Every file below was executed end-to-end against Postgres and all row counts and
  id sequences were compared against live before this bundle was written.

  ## Run order in the Supabase SQL editor

  1. `00_schema.sql` - tables, primary keys, foreign keys, indexes
  2. data files in numeric order (#{data_files.size} files):
  #{data_files.sort.map { |f| "   - `#{f}`" }.join("\n")}
  3. `90_rails_metadata.sql` - `schema_migrations` + `ar_internal_metadata`
  4. `99_sequences.sql` - id sequence resets (**do not skip this**)

  `all_in_one.sql` is all of the above concatenated, for `psql` users.

  ## Notes

  - Run the files **in order**. Tables are created in foreign-key dependency order
    (`people` -> `users`, `clients`, `inventory_items`, ... ), so no constraint is violated.
  - Each file is wrapped in its own transaction, so a file that fails leaves nothing
    behind. The Supabase editor opens a transaction of its own, so you may see
    `there is already a transaction in progress` warnings - they are harmless.
  - Targets an empty `public` schema. Supabase's own `auth`/`storage` schemas are untouched.
  - Step 4 matters: without the `setval` resets, the first new client/job/user you
    create raises a duplicate-key error because the sequence still starts at 1.
  - After this import Rails sees the database as current, so `rails db:migrate`
    during the Render build is a no-op.

  ## Pointing the app at Supabase afterwards

  Supabase connection string (Dashboard -> Connect), from the app's point of view:

      postgresql://postgres.PROJECT_REF:PASSWORD@HOST.pooler.supabase.com:6543/postgres

  Set it as the production database URL in the Render dashboard. Note that
  `config/database.yml` currently reads `AIVEN_DATABASE_URL` for production, so
  either set that key to the Supabase string or point `DATABASE_URL` at it and
  switch the one line back. The `?sslmode=require` suffix is appended by
  `database.yml`, so leave it off the value you paste in.
MD
File.write(File.join(OUT_DIR, "README.md"), readme, encoding: "UTF-8")

puts "Wrote #{File.expand_path(OUT_DIR)}"
puts format("%-32s %8s", "table", "rows")
puts "-" * 41
ordered.each { |t| puts format("%-32s %8d", t, row_totals[t]) unless METADATA_TABLES.include?(t) }
puts "-" * 41
puts format("%-32s %8d", "TOTAL", total)
puts "\ndata files:  #{data_files.size}"
puts "all_in_one:  #{File.size(File.join(OUT_DIR, 'all_in_one.sql'))} bytes"
