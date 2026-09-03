class PurchaseOrderItem < ApplicationRecord
  belongs_to :purchase_order

  validates :description, :quantity, :unit_price, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }

  def total
    (quantity || 0) * (unit_price || 0)
  end
end
