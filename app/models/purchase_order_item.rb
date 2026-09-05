class PurchaseOrderItem < ApplicationRecord
  belongs_to :purchase_order
  belongs_to :inventory_item, optional: true

  validates :description, :quantity, :unit_price, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }

  def total
    (quantity || 0) * (unit_price || 0)
  end

  def resolved_name
    inventory_item&.name || description
  end
end
