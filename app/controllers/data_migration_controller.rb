class DataMigrationController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :verify_migration_secret, only: [:migrate_to_aiven]

  def migrate_to_aiven
    source_url = ENV['DATABASE_URL']
    target_url = ENV['AIVEN_DATABASE_URL']

    if target_url.blank?
      render plain: "AIVEN_DATABASE_URL not set", status: :internal_server_error and return
    end

    require 'pg'
    src = PG.connect(source_url)
    tgt = PG.connect(target_url)
    skip_tables = %w[schema_migrations ar_internal_metadata]
    tgt.exec("SET session_replication_role = 'replica';")

    tables_result = src.exec("SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename NOT IN ('#{skip_tables.join("','")}') ORDER BY tablename")
    tables = tables_result.map { |r| r['tablename'] }

    log = []
    log << "Found #{tables.size} tables: #{tables.join(', ')}"

    tables.each do |table|
      count = src.exec("SELECT COUNT(*) FROM #{table}").first['count'].to_i
      cols = src.exec("SELECT column_name FROM information_schema.columns WHERE table_name = '#{table}' ORDER BY ordinal_position").map { |r| r['column_name'] }

      next if cols.empty?

      log << "Copying #{table}: #{count} rows"
      tgt.exec("TRUNCATE TABLE \"#{table}\" CASCADE;")

      if count > 0
        rows = src.exec("SELECT * FROM #{table}")
        rows.each do |row|
          col_names = cols.map { |c| "\"#{c}\"" }.join(', ')
          placeholders = cols.map.with_index { |_, i| "$#{i + 1}" }.join(', ')
          values = cols.map { |c| row[c] }
          tgt.exec_params("INSERT INTO \"#{table}\" (#{col_names}) VALUES (#{placeholders})", values)
        end
      end
    end

    tgt.exec("SET session_replication_role = 'DEFAULT';")

    src_migrations = src.exec("SELECT * FROM schema_migrations")
    src_migrations.each do |row|
      tgt.exec_params("INSERT INTO schema_migrations (version) VALUES ($1) ON CONFLICT (version) DO NOTHING", [row['version']])
    end

    log << "Done! #{tables.size} tables copied to Aiven."
    src.close
    tgt.close

    render plain: log.join("\n"), status: :ok
  end

  private

  def verify_migration_secret
    expected = ENV['MIGRATION_SECRET'] || 'migrate2026'
    unless params[:secret] == expected
      render plain: "Unauthorized", status: :unauthorized
    end
  end
end
