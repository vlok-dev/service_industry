#!/usr/bin/env ruby
# Prints the live schema shape so the Supabase dump can match it exactly.
# Usage: bundle exec ruby scripts/inspect_live_schema.rb
require "pg"
require "dotenv"

Dotenv.load(".env")
conn = PG.connect(ENV.fetch("AIVEN_DATABASE_URL"))

puts "server_version: #{conn.exec("SHOW server_version").first["server_version"]}"
puts "extensions:"
conn.exec("SELECT extname, extversion FROM pg_extension ORDER BY extname").each do |r|
  puts "  #{r['extname']} #{r['extversion']}"
end

puts "\nserial-backed columns:"
conn.exec(<<~SQL).each { |r| puts "  #{r['table']}.#{r['column']} -> #{r['seq']}" }
  SELECT c.relname AS table, a.attname AS column, pg_get_serial_sequence(c.relname, a.attname) AS seq
  FROM pg_attribute a
  JOIN pg_class c ON c.oid = a.attrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname='public' AND a.attnum>0 AND NOT a.attisdropped
    AND pg_get_serial_sequence(c.relname, a.attname) IS NOT NULL
  ORDER BY 1,2
SQL

puts "\ncolumns with non-null DEFAULT other than serial:"
conn.exec(<<~SQL).each { |r| puts "  #{r['table']}.#{r['column']} #{r['type']} default #{r['def']}" }
  SELECT c.relname AS table, a.attname AS column, format_type(a.atttypid,a.atttypmod) AS type,
         pg_get_expr(d.adbin,d.adrelid) AS def
  FROM pg_attribute a
  JOIN pg_class c ON c.oid=a.attrelid
  JOIN pg_namespace n ON n.oid=c.relnamespace
  JOIN pg_type t ON t.oid=a.atttypid
  LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum
  WHERE n.nspname='public' AND a.attnum>0 AND NOT a.attisdropped
    AND d.adbin IS NOT NULL
    AND pg_get_serial_sequence(c.relname, a.attname) IS NULL
  ORDER BY 1,2
SQL

puts "\narray / json / enum columns (need special literal handling):"
conn.exec(<<~SQL).each { |r| puts "  #{r['table']}.#{r['column']} #{r['type']}" }
  SELECT c.relname AS table, a.attname AS column, format_type(a.atttypid,a.atttypmod) AS type
  FROM pg_attribute a
  JOIN pg_class c ON c.oid=a.attrelid
  JOIN pg_namespace n ON n.oid=c.relnamespace
  JOIN pg_type t ON t.oid=a.atttypid
  WHERE n.nspname='public' AND a.attnum>0 AND NOT a.attisdropped
    AND (t.typtype='e' OR t.typelem<>0 OR t.typname IN ('json','jsonb'))
  ORDER BY 1,2
SQL

puts "\nforeign keys:"
conn.exec(<<~SQL).each { |r| puts "  #{r['table']}: #{r['def']}" }
  SELECT c.relname AS table, pg_get_constraintdef(k.oid) AS def
  FROM pg_constraint k
  JOIN pg_class c ON c.oid=k.conrelid
  JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' AND k.contype='f'
  ORDER BY 1
SQL

puts "\nunique constraints (contype='u'):"
conn.exec(<<~SQL).each { |r| puts "  #{r['table']}: #{r['def']}" }
  SELECT c.relname AS table, pg_get_constraintdef(k.oid) AS def
  FROM pg_constraint k
  JOIN pg_class c ON c.oid=k.conrelid
  JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' AND k.contype='u'
  ORDER BY 1
SQL

puts "\nnon-unique indexes:"
conn.exec(<<~SQL).each { |r| puts "  #{r['table']}: #{r['def']}" }
  SELECT t.relname AS table, pg_get_indexdef(i.indexrelid) AS def
  FROM pg_index i
  JOIN pg_class ix ON ix.oid=i.indexrelid
  JOIN pg_class t ON t.oid=i.indrelid
  JOIN pg_namespace n ON n.oid=t.relnamespace
  WHERE n.nspname='public' AND NOT i.indisprimary AND NOT i.indisunique
  ORDER BY 1
SQL

conn.close
