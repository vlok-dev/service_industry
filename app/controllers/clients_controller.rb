require "csv"

class ClientsController < ApplicationController
  before_action :require_manager, except: %i[ index show ]
  before_action :set_client, only: %i[ show edit update destroy ]

  def import
  end

  def import_create
    if params[:file].blank?
      redirect_back(fallback_location: clients_path, alert: "Please select a CSV file to upload.")
      return
    end

    file = params[:file]
    unless file.content_type == "text/csv" || File.extname(file.original_filename) == ".csv"
      redirect_back(fallback_location: clients_path, alert: "File must be a CSV.")
      return
    end

    imported = 0
    failed = 0
    tempfile = file.tempfile
    tempfile.rewind
    csv_text = tempfile.read
    rows = CSV.parse(csv_text, headers: true) || []
    rows.each_with_index do |row, idx|
      line_num = idx + 2
      name = (row["Name"] || "").strip
      surname = (row["Surname"] || "").strip
      company = (row["Company"] || "").strip
      contact_number = (row["Contact Number"] || "").strip
      address = (row["Address"] || "").strip
      email = (row["Email Address"] || "").strip

      client_name = company.present? ? company : [ name, surname ].reject(&:blank?).join(" ")
      if client_name.blank?
        failed += 1
        Rails.logger.warn "Skipping row #{line_num}: no name, surname, or company"
        next
      end

      client = Client.new(
        first_name: name,
        last_name: surname,
        company: company,
        phone_number: contact_number,
        address: address,
        email: email
      )
      if client.save
        imported += 1
      else
        failed += 1
        Rails.logger.warn "Failed to import row #{line_num}: #{client.errors.full_messages.join(', ')}"
      end
    end

    redirect_to clients_path, notice: "#{imported} clients imported successfully#{" (#{failed} failed)" if failed > 0}."
  end

  def index
    @clients = Client.ordered
    if params[:q].present?
      term = "%#{Client.sanitize_sql_like(params[:q].to_s.strip)}%"
      @clients = @clients.where(
        "LOWER(name) LIKE LOWER(:q) OR LOWER(contact_person) LIKE LOWER(:q) OR LOWER(phone_number) LIKE LOWER(:q) OR LOWER(email) LIKE LOWER(:q)",
        q: term
      )
    end
  end

  def show
  end

  def new
    @client = Client.new
  end

  def create
    @client = Client.new(client_params)
    if @client.save
      redirect_to clients_path, notice: "Client #{@client.name} was created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @client.update(client_params)
      redirect_to clients_path, notice: "Client was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @client.jobs.exists?
      redirect_back(fallback_location: clients_path, alert: "Cannot delete client with existing jobs. Reassign those jobs first.")
      return
    end
    @client.destroy
    redirect_to clients_path, notice: "Client was deleted."
  end

  private

  def require_manager
    return if current_user.admin? || current_user.super_admin?

    redirect_back(fallback_location: root_path, alert: "You are not authorized to manage clients.")
  end

  def set_client
    @client = Client.find(params[:id])
  end

  def client_params
    params.require(:client).permit(:first_name, :last_name, :company, :contact_person, :phone_number, :email, :address)
  end
end
