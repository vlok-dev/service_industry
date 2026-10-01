class DataMigrationController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :verify_migration_secret, only: [:migrate_to_aiven]

  def migrate_to_aiven
    source_url = ENV['DATABASE_URL']
    target_url = ENV['AIVEN_DATABASE_URL']

    Rails.logger.info "Migration source: #{source_url&.gsub(/:\/\/.*:.*@/, '://***:***@')}"
    Rails.logger.info "Migration target: #{target_url&.gsub(/:\/\/.*:.*@/, '://***:***@')}"

    if target_url.blank?
      render plain: "ERROR: AIVEN_DATABASE_URL not set. Check Render Dashboard -> Environment.", status: :internal_server_error and return
    end

    require 'pg'
    log = []

    begin
      log << "Connecting to source (Render Postgres)..."
      src = PG.connect(add_query_params(source_url, 'connect_timeout=10&application_name=render_migration'))
      log << "Source connected."

      log << "Connecting to target (Aiven)..."
      tgt = PG.connect(add_query_params(target_url, 'connect_timeout=10&application_name=render_migration'))
      log << "Target connected."

      skip_tables = %w[schema_migrations ar_internal_metadata]
      tgt.exec("SET session_replication_role = 'replica';")

      tables_result = src.exec("SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename NOT IN ('#{skip_tables.join("','")}') ORDER BY tablename")
      tables = tables_result.map { |r| r['tablename'] }

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
            tgt.exec_params("INSERT INTO \"#{table}\" (#{col_names}) VALUES (#{placeholders}) ON CONFLICT DO NOTHING", values)
          end
          log << "  Copied #{count} rows to #{table}"
        else
          log << "  Empty table (#{table})"
        end
      end

      tgt.exec("SET session_replication_role = 'DEFAULT';")

      src_migrations = src.exec("SELECT * FROM schema_migrations")
      src_migrations.each do |row|
        tgt.exec_params("INSERT INTO schema_migrations (version) VALUES ($1) ON CONFLICT (version) DO NOTHING", [row['version']])
      end

      log << "Done! #{tables.size} tables processed."
      src.close
      tgt.close

      render plain: log.join("\n"), status: :ok
    rescue => e
      log << "ERROR: #{e.class}: #{e.message}"
      log << e.backtrace.first(5).join("\n") if e.backtrace
      Rails.logger.error "Migration failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if e.backtrace
      render plain: log.join("\n"), status: :internal_server_error
    end
  end

  private

  def verify_migration_secret
    expected = ENV['MIGRATION_SECRET'] || 'migrate2026'
    unless params[:secret] == expected
      render plain: "Unauthorized", status: :unauthorized
    end
  end

  def add_query_params(url, params_str)
    if url.include?('?')
      "#{url}&#{params_str}"
    else
      "#{url}?#{params_str}"
    end
  end
end
