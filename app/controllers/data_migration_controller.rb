class DataMigrationController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :verify_migration_secret, only: [:run]

  def migrate_to_aiven
    render plain: "Migration endpoint ready. Hit /run_migration?secret=migrate2026 or /run_migration?secret=migrate2026&tables=jobs,purchase_orders to copy specific tables only", status: :ok
  end

  def run
    source_url = ENV['DATABASE_URL']
    target_url = ENV['AIVEN_DATABASE_URL']
    only_tables = params[:tables].present? ? params[:tables].split(',').map(&:strip) : nil

    if target_url.blank?
      render plain: "ERROR: AIVEN_DATABASE_URL not set in Render Dashboard -> Environment", status: :internal_server_error and return
    end
    if source_url.blank?
      render plain: "ERROR: DATABASE_URL (Render Postgres) not set", status: :internal_server_error and return
    end

    require 'pg'
    log = []
    log << "Source: #{source_url.gsub(/:\/\/.*:.*@/, '://***:***@')}"
    log << "Target: #{target_url.gsub(/:\/\/.*:.*@/, '://***:***@')}"
    log << "Tables: #{only_tables&.join(', ') || 'all (alphabetical)'}"

    begin
      src = PG.connect(source_url)
      tgt = PG.connect(target_url)

      skip_tables = %w[schema_migrations ar_internal_metadata]
      tgt.exec("SET session_replication_role = 'replica';")

      sql = "SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename NOT IN ('#{skip_tables.join("','")}') ORDER BY tablename"
      tables = src.exec(sql).map { |r| r['tablename'] }

      if only_tables
        tables = tables.select { |t| only_tables.include?(t) }
        log << "Selected tables: #{tables.join(', ')}"
      else
        log << "Found #{tables.size} tables"
      end

      tables.each do |table|
        count = src.exec("SELECT COUNT(*) FROM #{table}").first['count'].to_i
        cols = src.exec("SELECT column_name FROM information_schema.columns WHERE table_name='#{table}' ORDER BY ordinal_position").map { |r| r['column_name'] }

        log << "#{table}: #{count} rows"

        # Check if target already has data - skip TRUNCATE if empty
        target_count = tgt.exec("SELECT COUNT(*) FROM \"#{table}\"").first['count'].to_i

        if only_tables
          if target_count > 0
            tgt.exec("DELETE FROM \"#{table}\"")
            log << "  Cleared #{target_count} existing rows"
          else
            log << "  Target already empty, skipping clear"
          end
        else
          tgt.exec("TRUNCATE TABLE \"#{table}\" CASCADE;")
        end

        if count > 0
          col_names = cols.map { |c| "\"#{c}\"" }.join(', ')
          tgt.copy_data("COPY #{table} (#{col_names}) FROM STDIN WITH (FORMAT csv)") do
            src.copy_data("COPY #{table} TO STDOUT WITH (FORMAT csv)") do
              while data = src.get_copy_data
                tgt.put_copy_data(data)
              end
            end
          end
          log << "  Copied #{count} rows"
        else
          log << "  Skipped (empty)"
        end
      end

      src.exec("SELECT version FROM schema_migrations").each do |row|
        tgt.exec_params("INSERT INTO schema_migrations (version) VALUES ($1) ON CONFLICT (version) DO NOTHING", [row['version']])
      end

      log << "Done! #{tables.size} tables processed."
      tgt.exec("SET session_replication_role = 'origin';")
      src.close
      tgt.close
      render plain: log.join("\n"), status: :ok
    rescue => e
      log << "ERROR: #{e.class}: #{e.message}"
      Rails.logger.error "Migration error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if e.backtrace
      render plain: log.join("\n"), status: :internal_server_error
    end
  end

  private

  def verify_migration_secret
    unless params[:secret] == (ENV['MIGRATION_SECRET'] || 'migrate2026')
      render plain: "Unauthorized", status: :unauthorized
    end
  end
end
