class Quote < ApplicationRecord
  belongs_to :job, optional: true
  belongs_to :created_by, class_name: "User", optional: true

  has_many :items, class_name: "QuoteItem", dependent: :destroy
  accepts_nested_attributes_for :items, allow_destroy: true, reject_if: :all_blank

  enum :status, { draft: 0, sent: 1, accepted: 2, rejected: 3 }

  before_save :persist_totals
  before_validation :assign_quote_number, on: :create

  validates :quote_number, presence: true, uniqueness: { case_sensitive: false }
  validates :vat_rate, numericality: { greater_than: 0 }, allow_blank: true

  def subtotal
    items.sum { |item| item.total_price.to_f }
  end

  def vat_amount
    subtotal * (vat_rate.to_f / 100.0)
  end

  def total_including_vat
    subtotal + vat_amount
  end

  def quote_date_value
    quote_date || created_at&.to_date || Date.current
  end

  def formatted_date
    dt = quote_date_value
    "#{dt.day} #{dt.strftime('%B')} #{dt.year}".upcase
  end

  def company_name
    company.presence || job&.customer_name.presence || "CLC"
  end

  def customer_name
    job&.customer_name
  end

  def job_number
    job&.job_number
  end

  def customer_attention
    attention.presence || job&.contact_person.presence || "Tiisetso Mohlohlo"
  end

  def customer_email
    email_address.presence || job&.email.presence || "cca@clc.co.za"
  end

  def property_address
    property.presence || job&.address.presence || "73B Omar Cassim Street, Overbaakens"
  end

  def job_subject
    subject.presence || job&.description.presence || "REPLACE GEYSERWISE"
  end

  def self.next_quote_number
    last = Quote.order(:id).last
    next_num = last&.id.to_i + 1
    "QT-#{next_num.to_s.rjust(5, '0')}"
  end

  private

  def persist_totals
    items.each do |item|
      item.total_price = item.unit_price if item.unit_price.present?
    end
  end

  def assign_quote_number
    self.quote_number ||= Quote.next_quote_number
  end
end
