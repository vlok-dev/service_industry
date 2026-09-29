class DigitalJobCardsController < ApplicationController
  include Pagy::Method
  before_action :authenticate_user!
  before_action :set_digital_job_card, only: %i[ show edit update destroy print ]
  before_action :authorize_access!, only: %i[ show edit update destroy print ]
  before_action :set_inventory_items, only: %i[ index new create edit update ]

  def index
    @digital_job_cards = policy_scope(DigitalJobCard).recent
    if params[:q].present?
      term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip)}%"
      @digital_job_cards = @digital_job_cards.where(
        "LOWER(client_name) LIKE LOWER(:q) OR LOWER(address) LIKE LOWER(:q) OR LOWER(description) LIKE LOWER(:q)",
        q: term
      )
    end
    @pagy, @digital_job_cards = pagy(@digital_job_cards, limit: 20)
    @digital_job_card = DigitalJobCard.new
  end

  def show
  end

  def new
    @digital_job_card = DigitalJobCard.new
  end

  def create
    @digital_job_card = current_user.digital_job_cards.build(digital_job_card_params)

    if @digital_job_card.save
      redirect_to digital_job_cards_path, notice: "Digital job card created successfully."
    else
      @digital_job_cards = current_user.digital_job_cards.recent
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @digital_job_card.update(digital_job_card_params)
      redirect_to digital_job_cards_path, notice: "Digital Job Card updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    job = @digital_job_card.job
    @digital_job_card.destroy
    if job
      redirect_to job_path(job), notice: "Extra work deleted."
    else
      redirect_to digital_job_cards_path, notice: "Extra work deleted."
    end
  end

  def print
    @materials = @digital_job_card.materials.material_lines
    @labor_items = @digital_job_card.materials.labor_lines
    @total_materials = @digital_job_card.materials_total
    @total_labor = @digital_job_card.labor_total
    @grand_total = @digital_job_card.grand_total

    render layout: 'print'
  end

  private

  def set_digital_job_card
    @digital_job_card = policy_scope(DigitalJobCard).find(params[:id])
  end

  def authorize_access!
    unless @digital_job_card.user == current_user || current_user.super_admin? || current_user.admin? || current_user.reporter? || current_user.scheduler?
      redirect_to dashboard_path, alert: "Not authorized."
    end
  end

  def set_inventory_items
    @inventory_items = InventoryItem.active.order(:code)
  end

  def digital_job_card_params
    params.require(:digital_job_card).permit(:client_id, :client_name, :address, :date, :time_start, :time_finish, :description, materials_attributes: [:id, :inventory_item_id, :material_name, :quantity, :unit_price, :markup, :labor_rate, :hours_worked, :is_labor, :_destroy])
  end
end