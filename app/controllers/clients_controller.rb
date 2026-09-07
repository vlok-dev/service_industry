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
       customer_code = (row["Customer Code"] || "").strip
       customer_name = (row["Customer Name"] || "").strip
       company = customer_name
       primary_contact = (row["Primary Contact"] || "").strip
       email = (row["Primary Contact Email"] || "").strip
       mobile = (row["Primary Contact Mobile"] || "").strip
       delivery_address = (row["Primary Delivery Address"] || "").strip
       postal_address = (row["Primary Postal Address"] || "").strip

       if customer_name.blank?
         failed += 1
         Rails.logger.warn "Skipping row #{line_num}: no customer name or company"
         next
       end

       if primary_contact.present?
        name_parts = primary_contact.strip.split
        first_name = name_parts.first
        last_name = name_parts.length > 1 ? name_parts[1..].join(" ") : ""
      else
        first_name = ""
        last_name = ""
      end

       client = Client.new(
         customer_code: customer_code,
         first_name: first_name,
         last_name: last_name,
         company: company,
         contact_person: primary_contact.presence || [ first_name, last_name ].reject(&:blank?).join(" "),
         email: email,
         primary_contact_mobile: mobile,
         delivery_address: delivery_address,
         postal_address: postal_address,
         phone_number: mobile
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
         "LOWER(name) LIKE LOWER(:q) OR LOWER(contact_person) LIKE LOWER(:q) OR LOWER(primary_contact_mobile) LIKE LOWER(:q) OR LOWER(email) LIKE LOWER(:q) OR LOWER(customer_code) LIKE LOWER(:q)",
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
    params.require(:client).permit(:customer_code, :first_name, :last_name, :company, :contact_person, :email, :primary_contact_mobile, :delivery_address, :postal_address, :phone_number)
  end
end
