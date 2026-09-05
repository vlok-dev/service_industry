class PurchaseOrder < ApplicationRecord
  belongs_to :job
  belongs_to :created_by, class_name: "User"
  belongs_to :supplier, optional: true

  has_many :items, class_name: "PurchaseOrderItem", dependent: :destroy
  accepts_nested_attributes_for :items, allow_destroy: true, reject_if: :all_blank

  before_save :persist_total_amount
  before_validation :sync_supplier_name
  before_validation :assign_po_number, on: :create

  validates :supplier_name, presence: true
  validates :order_date, presence: true

  def supplier_display_name
    supplier&.name || supplier_name
  end

  def subtotal
    items.sum { |item| (item.quantity || 0) * (item.unit_price || 0) }
  end

  def vat_amount
    subtotal * (vat_rate / 100.0)
  end

  def total_including_vat
    subtotal + vat_amount
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

  def sync_supplier_name
    self.supplier_name = supplier&.name if supplier_id_changed? && supplier.present?
  end

  # Persist the total after VAT (15% by default) so the PO always carries a
  # concrete total amount rather than recomputing it on every read.
  def persist_total_amount
    self.total_amount = total_including_vat
  end

  def assign_po_number
    self.po_number ||= PurchaseOrder.next_po_number
  end
end
