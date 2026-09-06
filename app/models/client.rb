class Client < ApplicationRecord
  has_many :jobs, dependent: :restrict_with_error

  validates :name, :address, presence: true
  validates :email, format: { with: /\A[^@\s]+@[^@\s]+\z/, message: "must look like an email address" }, allow_blank: true
  validates :phone_number, format: { with: /\A[0-9+\s\-().]+\z/, message: "can only contain numbers, spaces and + - () ." }, allow_blank: true
  validate :must_have_name_or_company

  before_validation :set_client_name
  before_validation :set_contact_person

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
  end

  def set_contact_person
    self.contact_person = [ first_name, last_name ].reject(&:blank?).join(" ")
  end

  def must_have_name_or_company
    if company.blank? && [ first_name, last_name ].all?(&:blank?)
      errors.add(:base, "Either Company or Name must be provided")
    end
  end
end
