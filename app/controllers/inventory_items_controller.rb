require "csv"

class InventoryItemsController < ApplicationController
  before_action :require_manager, except: %i[ index search import import_create ]
  before_action :set_inventory_item, only: %i[ show edit update destroy ]

  def index
    @inventory_items = InventoryItem.order(:code)
    if params[:q].present?
      term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.strip)}%"
      @inventory_items = @inventory_items.where("LOWER(code) LIKE LOWER(:q) OR LOWER(name) LIKE LOWER(:q)", q: term)
    end
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

  def import
  end

  def import_create
    if params[:file].blank?
      redirect_back(fallback_location: inventory_items_path, alert: "Please select a CSV file to upload.")
      return
    end

    file = params[:file]
    unless file.content_type == "text/csv" || File.extname(file.original_filename) == ".csv"
      redirect_back(fallback_location: inventory_items_path, alert: "File must be a CSV.")
      return
    end

    imported = 0
    updated = 0
    failed = 0

    tempfile = file.tempfile
    tempfile.rewind
    csv_text = tempfile.read.force_encoding("UTF-8").sub(/\A\xEF\xBB\xBF/, "")
    rows = CSV.parse(csv_text, headers: true) || []
    rows = rows.map { |r| r.to_h.transform_keys { |k| k.to_s.strip } }

    rows.each_with_index do |row, idx|
      line_num = idx + 2

      code = (row["Code"] || "").strip
      name = (row["Description"] || "").strip
      stock_item_type = (row["Stock Item Type"] || "").strip.presence
      total_stock_quantity = row["Total Stock Quantity"]
      cost_price = row["Cost Price"]
      list_price = row["List Price"]
      replacement_percentage = row["Replacement Percentage"]
      is_serializable = row["Is Serializable"]
      is_quantity_tracked = row["Is Quantity Tracked"]
      is_active = row["Is Active"]
      created_by = (row["Created By"] || "").strip.presence
      modified_by = (row["Modified By"] || "").strip.presence

      if code.blank? || name.blank?
        failed += 1
        Rails.logger.warn "Skipping row #{line_num}: missing code or description"
        next
      end

      attrs = {
        name: name,
        stock_item_type: stock_item_type,
        total_stock_quantity: parse_decimal(total_stock_quantity),
        cost_price: parse_decimal(cost_price),
        list_price: parse_decimal(list_price),
        unit_price: parse_decimal(list_price),
        replacement_percentage: parse_decimal(replacement_percentage),
        is_serializable: parse_bool(is_serializable),
        is_quantity_tracked: parse_bool(is_quantity_tracked, default: true),
        is_active: parse_bool(is_active, default: true),
        created_by: created_by,
        modified_by: modified_by
      }

      item = InventoryItem.find_or_initialize_by(code: code)
      is_new = item.new_record?
      item.assign_attributes(attrs)
      item.modified_by ||= modified_by

      if item.save
        is_new ? imported += 1 : updated += 1
      else
        failed += 1
        Rails.logger.warn "Failed to import row #{line_num}: #{item.errors.full_messages.join(', ')}"
      end
    end

    notice = "#{imported} items imported"
    notice += ", #{updated} updated" if updated.positive?
    notice += " (#{failed} failed)" if failed.positive?
    redirect_to inventory_items_path, notice: notice + "."
  end

  private

  def parse_decimal(value)
    return nil if value.nil?
    s = value.to_s.strip
    return nil if s.empty?
    s.gsub(/[^\d.\-]/, "")
  end

  def parse_bool(value, default: false)
    return default if value.nil?
    s = value.to_s.strip.downcase
    return default if s.empty?
    %w[1 true yes y t].include?(s)
  end

  def require_manager
    return if current_user.admin? || current_user.super_admin?

    redirect_back(fallback_location: root_path, alert: "You are not authorized to manage inventory.")
  end

  def set_inventory_item
    @inventory_item = InventoryItem.find(params[:id])
  end

  def inventory_item_params
    params.require(:inventory_item).permit(:code, :name, :description, :unit_price, :unit, :stock_item_type, :total_stock_quantity, :cost_price, :list_price, :replacement_percentage, :is_serializable, :is_quantity_tracked, :is_active, :created_by, :modified_by)
  end
end
