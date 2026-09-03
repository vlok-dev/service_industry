class PurchaseOrder < ApplicationRecord
  belongs_to :job
  belongs_to :created_by, class_name: "User"

  has_many :items, class_name: "PurchaseOrderItem", dependent: :destroy
  accepts_nested_attributes_for :items, allow_destroy: true, reject_if: :all_blank

  enum :status, { draft: 0, submitted: 1, approved: 2, received: 3, cancelled: 4 }

  before_validation :assign_po_number, on: :create

  validates :supplier_name, presence: true
  validates :order_date, presence: true

  def subtotal
    items.sum { |item| (item.quantity || 0) * (item.unit_price || 0) }
  end

  def item_count
    items.sum(:quantity)
  end

  def self.next_po_number
    last = PurchaseOrder.order(:id).last
    next_num = last&.id.to_i + 1
    "PO-#{next_num.to_s.rjust(5, '0')}"
  end

  private

  def assign_po_number
    self.po_number ||= PurchaseOrder.next_po_number
  end
end
