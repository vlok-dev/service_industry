class InventoryItemsController < ApplicationController
  before_action :require_manager, except: %i[ index search ]
  before_action :set_inventory_item, only: %i[ show edit update destroy ]

  def index
    @inventory_items = InventoryItem.order(:code)
    @inventory_items = @inventory_items.where("code ILIKE :q OR name ILIKE :q", q: "%#{params[:q]}%") if params[:q].present?
  end

  def show
  end

  def new
    @inventory_item = InventoryItem.new
  end

  def create
    @inventory_item = InventoryItem.new(inventory_item_params)
    if @inventory_item.save
      redirect_to inventory_items_path, notice: "Inventory item #{@inventory_item.code} was created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @inventory_item.update(inventory_item_params)
      redirect_to inventory_items_path, notice: "Inventory item was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @inventory_item.destroy
    redirect_to inventory_items_path, notice: "Inventory item was deleted."
  end

  def search
    @results = InventoryItem.search_by_code(params[:q])
    render json: @results.as_json(only: %i[id code name unit_price unit]), status: :ok
  end

  private

  def require_manager
    return if current_user.admin? || current_user.super_admin?

    redirect_back(fallback_location: root_path, alert: "You are not authorized to manage inventory.")
  end

  def set_inventory_item
    @inventory_item = InventoryItem.find(params[:id])
  end

  def inventory_item_params
    params.require(:inventory_item).permit(:code, :name, :description, :unit_price, :unit)
  end
end
