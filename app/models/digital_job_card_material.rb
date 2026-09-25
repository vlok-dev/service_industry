class DigitalJobCardMaterial < ApplicationRecord
  belongs_to :digital_job_card
  belongs_to :inventory_item, optional: true

  validates :material_name, presence: true
  validates :quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :markup, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :labor_rate, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  def calculated_total
    (unit_price * quantity * (1 + (markup || 0) / 100)) + (labor_rate || 0)
  end
end
