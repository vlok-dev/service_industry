class DataMigrationController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :verify_migration_secret, only: [:migrate_to_aiven, :export_sql]

  # Export Render Postgres data as a downloadable SQL file
  def export_sql
    conn = ActiveRecord::Base.connection
    log = []
    sql_lines = []

    tables = conn.exec_query("SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename NOT IN ('schema_migrations', 'ar_internal_metadata') ORDER BY tablename")

    sql_lines << "-- Data export from Render Postgres"
    sql_lines << "-- Generated at: #{Time.current}"
    sql_lines << "SET session_replication_role = 'replica';"
    sql_lines << ""

    tables.each do |t|
      table = t['tablename']
      count = conn.exec_query("SELECT COUNT(*) as c FROM #{table}").first['c']
      cols = conn.columns(table).map { |c| c.name }

      log << "#{table}: #{count} rows, columns: #{cols.join(', ')}"

      sql_lines << "-- Table: #{table} (#{count} rows)"
      sql_lines << "TRUNCATE TABLE \"#{table}\" CASCADE;"

      if count > 0
        offset = 0
        batch_size = 50
        while offset < count
          rows = conn.exec_query("SELECT * FROM #{table} ORDER BY id LIMIT #{batch_size} OFFSET #{offset}")
          rows.each do |row|
            values = cols.map do |col|
              val = row[col]
              val.nil? ? 'NULL' : "'#{val.to_s.gsub("'", "''")}'"
            end
            col_names = cols.map { |c| "\"#{c}\"" }.join(', ')
            vals = values.join(', ')
            sql_lines << "INSERT INTO \"#{table}\" (#{col_names}) VALUES (#{vals});"
          end
          offset += batch_size
        end
      end
      sql_lines << ""
    end

    sql_lines << "SET session_replication_role = 'DEFAULT';"

    # Also include schema_migrations
    sql_lines << "-- schema_migrations"
    migrations = conn.exec_query("SELECT version FROM schema_migrations").map { |r| r['version'] }
    migrations.each do |v|
      sql_lines << "INSERT INTO schema_migrations (version) VALUES ('#{v}') ON CONFLICT (version) DO NOTHING;"
    end

    send_data sql_lines.join("\n"), filename: "render_to_aiven_#{Time.current.to_i}.sql", type: 'text/sql'
  end

  def migrate_to_aiven
    render plain: "Use /export_sql?secret=migrate2026 to download SQL, then import to Aiven console", status: :ok
  end

  private

  def verify_migration_secret
    expected = ENV['MIGRATION_SECRET'] || 'migrate2026'
    unless params[:secret] == expected
      render plain: "Unauthorized", status: :unauthorized
    end
  end
end
