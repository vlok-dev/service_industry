class DigitalJobCardsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_digital_job_card, only: %i[ show edit update destroy print ]
  before_action :authorize_access!, only: %i[ show edit update destroy print ]
  before_action :set_inventory_items, only: %i[ index new create edit update ]

  def index
    @digital_job_cards = policy_scope(DigitalJobCard).recent
    @digital_job_card = DigitalJobCard.new
  end

  def show
  end

  def new
    @digital_job_card = DigitalJobCard.new
  end

  def create
    @digital_job_card = current_user.digital_job_cards.build(digital_job_card_params)
    
    # Process materials to calculate totals
    if @digital_job_card.materials.any?
      @digital_job_card.materials.each do |material|
        if material.inventory_item_id.present? && material.unit_price.zero?
          inventory_item = InventoryItem.find(material.inventory_item_id)
          material.unit_price = inventory_item.list_price || inventory_item.unit_price || inventory_item.cost_price || 0
          material.material_name = inventory_item.name if material.material_name.blank?
        end
        # Apply 30% markup if not set
        material.markup = 30 if material.markup.zero? && material.unit_price > 0 && !material.is_labor?
        material.total_price = material.calculated_total
      end
    end

    if @digital_job_card.save
      redirect_to digital_job_cards_path, notice: "Digital Job Card created successfully."
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
    @materials = @digital_job_card.materials.where(is_labor: false)
    @labor_items = @digital_job_card.materials.where(is_labor: true)
    @total_materials = @materials.sum(&:total_price)
    @total_labor = @labor_items.sum(&:total_price)
    @grand_total = @total_materials + @total_labor
    
    render layout: 'print'
  end

  private

  def set_digital_job_card
    @digital_job_card = policy_scope(DigitalJobCard).find(params[:id])
  end

  def authorize_access!
    unless @digital_job_card.user == current_user || current_user.super_admin? || current_user.admin? || current_user.reporter?
      redirect_to dashboard_path, alert: "Not authorized."
    end
  end

  def set_inventory_items
    @inventory_items = InventoryItem.active.order(:code)
  end

  def digital_job_card_params
    params.require(:digital_job_card).permit(:client_id, :client_name, :address, :date, :time_start, :time_finish, :description, materials_attributes: [:id, :inventory_item_id, :material_name, :quantity, :unit_price, :markup, :labor_rate, :is_labor, :_destroy])
  end
end