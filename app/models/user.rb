class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum :role, { super_admin: 0, scheduler: 1, reporter: 2, plumber: 3, admin: 4 }

  has_many :assigned_jobs, class_name: "Job", foreign_key: :assigned_to_id, dependent: :nullify
  has_many :jobs, dependent: :nullify

  before_validation :generate_email_if_blank

  private

  def generate_email_if_blank
    if email.blank?
      base = name.to_s.downcase.parameterize.gsub(/[^a-z0-9]/, "")
      base = "user#{id || Time.now.to_i}" if base.blank?
      self.email = "#{base}@industroplumbers.local"
    end
  end
end
