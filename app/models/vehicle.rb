class Vehicle < ApplicationRecord
  has_many :vehicle_tools, dependent: :destroy
  accepts_nested_attributes_for :vehicle_tools, allow_destroy: true, reject_if: :all_blank

  validates :name, presence: true
  validates :current_mileage, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  scope :ordered, -> { order(:id) }

  def registration_status
    return "Unknown" if registration_expiry.blank?
    return "Expired" if registration_expiry < Date.current
    return "Due soon" if registration_expiry <= 30.days.from_now.to_date
    "Active"
  end

  def service_status
    return "Unknown" if next_service_due_date.blank?
    return "Overdue" if next_service_due_date < Date.current
    return "Due soon" if next_service_due_date <= 14.days.from_now.to_date
    "OK"
  end
end
