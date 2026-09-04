class User < ApplicationRecord
  devise :database_authenticatable,
         :recoverable,
         :rememberable,
         :validatable

  enum :role, { super_admin: 0, scheduler: 1, reporter: 2, plumber: 3, admin: 4, accountant: 5 }

  has_many :assigned_jobs, class_name: "Job", foreign_key: :assigned_to_id, dependent: :nullify
  has_many :jobs, dependent: :nullify

  validates :email, uniqueness: true, allow_nil: true, allow_blank: true
  validates :name, presence: true

  def email_required?
    false
  end
end
