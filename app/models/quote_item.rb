class QuoteItem < ApplicationRecord
  belongs_to :quote
  belongs_to :inventory_item, optional: true

  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true

  before_save :set_defaults, if: -> { unit_price.blank? || total_price.blank? }

  def line_total
    total_price || 0
  end

  private

  def set_defaults
    self.unit_price = 0 if unit_price.blank?
    self.total_price = 0 if total_price.blank?
  end
end
