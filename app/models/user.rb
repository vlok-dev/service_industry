class User < ApplicationRecord
  devise :database_authenticatable,
         :recoverable,
         :rememberable,
         :validatable

  enum :role, { super_admin: 0, scheduler: 1, reporter: 2, plumber: 3, admin: 4, accountant: 5 }

  has_many :assigned_jobs, class_name: "Job", foreign_key: :assigned_to_id, dependent: :nullify
  has_many :jobs, dependent: :nullify

  before_validation :normalize_email

  validates :email, uniqueness: { allow_nil: true }, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :name, presence: true

  def email_required?
    false
  end

  private

  def normalize_email
    self.email = nil if email.blank?
  end
end
