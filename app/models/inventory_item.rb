class InventoryItem < ApplicationRecord
  has_many :purchase_order_items, dependent: :nullify

  validates :code, :name, presence: true
  validates :code, uniqueness: { case_sensitive: false }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  def self.search_by_code(query)
    return none if query.blank?
    pattern = "%#{sanitize_sql_like(query.to_s.strip)}%"
    where("LOWER(code) LIKE LOWER(?)", pattern).order(:code).limit(20)
  end
end
