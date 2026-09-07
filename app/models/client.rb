class Client < ApplicationRecord
  has_many :jobs, dependent: :restrict_with_error

  validates :name, presence: true
  validates :email, format: { with: /\A[^@\s]+@[^@\s]+\z/, message: "must look like an email address" }, allow_blank: true
  validates :primary_contact_mobile, format: { with: /\A[0-9+\s\-().]+\z/, message: "can only contain numbers, spaces and + - () ." }, allow_blank: true
  validate :must_have_company_or_name

  before_validation :set_client_name

  def self.ordered
    order(:name)
  end

  private

  def set_client_name
    if company.present?
      self.name = company
    else
      self.name = [ first_name, last_name ].reject(&:blank?).join(" ")
    end
    self.contact_person = [ first_name, last_name ].reject(&:blank?).join(" ") if company.present?
  end

  def must_have_company_or_name
    if company.blank? && [ first_name, last_name ].all?(&:blank?)
      errors.add(:base, "Either Company or Name must be provided")
    end
  end
end
