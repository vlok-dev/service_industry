class RetentionsController < ApplicationController
  before_action :require_manager, except: %i[ index show ]
  before_action :set_retention, only: %i[ show edit update destroy ]

  def index
    @retentions = Retention.includes(:client).ordered
    if params[:q].present?
      term = "%#{Retention.sanitize_sql_like(params[:q].to_s.strip)}%"
      @retentions = @retentions.where(
        "LOWER(client_name) LIKE LOWER(:q) OR LOWER(project_name) LIKE LOWER(:q) OR LOWER(invoice_number) LIKE LOWER(:q)",
        q: term
      )
    end
  end

  def show
  end

  def new
    @retention = Retention.new
  end

  def create
    @retention = Retention.new(retention_params)
    @retention.client = resolve_client
    if @retention.save
      redirect_to retentions_path, notice: "Retention was created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @retention.client = resolve_client
    if @retention.update(retention_params)
      redirect_to retentions_path, notice: "Retention was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @retention.destroy
    redirect_to retentions_path, notice: "Retention was deleted."
  end

  private

  def require_manager
    return if current_user.admin? || current_user.super_admin?

    redirect_back(fallback_location: root_path, alert: "You are not authorized to manage retentions.")
  end

  def set_retention
    @retention = Retention.find(params[:id])
  end

  def resolve_client
    client_id = retention_params[:client_id]
    return Client.find(client_id) if client_id.present?

    name = retention_params[:client_name].to_s.strip
    return nil if name.blank?

    Client.find_or_create_by(name: name)
  end

  def retention_params
    params.require(:retention).permit(
      :client_id, :client_name, :project_name, :date_held,
      :amount, :invoice_number, :release_date
    )
  end
end
