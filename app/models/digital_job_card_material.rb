class DigitalJobCardMaterial < ApplicationRecord
  belongs_to :digital_job_card
  belongs_to :inventory_item, optional: true

  validates :material_name, presence: true
  validates :quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :markup, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :labor_rate, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :hours_worked, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  before_validation :apply_inventory_item_defaults
  before_validation :normalize_line
  before_validation :assign_total_price

  scope :material_lines, -> { where(is_labor: false) }
  scope :labor_lines, -> { where(is_labor: true) }

  def labor?
    is_labor? ? true : false
  end

  def material?
    !labor?
  end

  # Materials: unit price x qty x (1 + markup)
  # Labour:   rate x hours
  def line_total
    if labor?
      to_d(labor_rate) * to_d(hours_worked)
    else
      to_d(unit_price) * to_d(quantity) * (1 + to_d(markup) / 100)
    end
  end
  alias_method :calculated_total, :line_total

  private

  def to_d(value)
    value.blank? ? BigDecimal("0") : value.to_d
  end

  def apply_inventory_item_defaults
    return if labor? || inventory_item_id.blank?

    item = inventory_item || InventoryItem.find_by(id: inventory_item_id)
    return if item.nil?

    self.inventory_item_id = item.id
    self.unit_price = item.list_price || item.unit_price || item.cost_price || 0 if to_d(unit_price).zero?
    self.material_name = item.name if material_name.blank?
  end

  # Keep each line on a single costing basis so labour and material costs can
  # never bleed into each other when the form posts partial fields.
  def normalize_line
    if labor?
      self.quantity = 0
      self.unit_price = 0
      self.markup = 0
    else
      self.labor_rate = 0
      self.hours_worked = 0
    end
  end

  def assign_total_price
    self.total_price = line_total.round(2)
  end
end
