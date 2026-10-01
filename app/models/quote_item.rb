class QuoteItem < ApplicationRecord
  belongs_to :quote
  belongs_to :inventory_item, optional: true

  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true

  def line_total
    total_price || 0
  end
end
