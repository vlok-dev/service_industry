class User < ApplicationRecord
  devise :database_authenticatable,
         :recoverable,
         :rememberable,
         :validatable

  enum :role, { super_admin: 0, scheduler: 1, reporter: 2, plumber: 3, admin: 4, accountant: 5 }

  has_many :assigned_jobs, class_name: "Job", foreign_key: :assigned_to_id, dependent: :nullify
  has_many :jobs, dependent: :nullify
  has_many :reports, dependent: :destroy

  before_validation :normalize_email

  validates :email, uniqueness: { allow_nil: true }, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :name, presence: true

  def email_required?
    false
  end

  def dismissed_today?(entry_id)
    return false if dismissed_reminder_ids_raw.blank?
    today = Date.today.to_s
    JSON.parse(dismissed_reminder_ids_raw).any? { |pair| pair.to_s == "#{entry_id}:#{today}" }
  rescue JSON::ParserError
    false
  end

  def dismiss_reminder!(entry_id)
    pairs = dismissed_pairs
    pairs << "#{entry_id}:#{Date.today.to_s}" unless pairs.include?("#{entry_id}:#{Date.today.to_s}")
    update(dismissed_reminder_ids_raw: JSON.generate(pairs))
  end

  def dismissed_pairs
    return [] if dismissed_reminder_ids_raw.blank?
    JSON.parse(dismissed_reminder_ids_raw)
  rescue JSON::ParserError
    []
  end

  def reminder_dismissed_today?
    reminder_dismissed_at && reminder_dismissed_at >= Time.current.beginning_of_day
  end

  private

  def normalize_email
    self.email = nil if email.blank?
  end
end
