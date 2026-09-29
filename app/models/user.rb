class User < ApplicationRecord
  devise :database_authenticatable,
         :recoverable,
         :rememberable,
         :validatable

  enum :role, { super_admin: 0, scheduler: 1, reporter: 2, plumber: 3, admin: 4, accountant: 5, project_manager: 6 }

  # Anybody can pick up a second role for themselves, but the two roles that
  # hand out power stay with admins so nobody can promote themselves.
  ADMIN_ONLY_ROLES = %w[admin super_admin].freeze

  def self.self_serviceable_roles
    roles.keys - ADMIN_ONLY_ROLES
  end

  belongs_to :person, inverse_of: :profiles

  has_many :assigned_jobs, class_name: "Job", foreign_key: :assigned_to_id, dependent: :nullify
  has_many :jobs, dependent: :nullify
  has_many :reports, dependent: :destroy
  has_many :digital_job_cards, dependent: :destroy

  before_validation :normalize_email, :ensure_person

  # Roles that default to dark mode. Everyone else defaults to light.
  DARK_MODE_ROLES = %w[super_admin scheduler admin].freeze

  def self.role_default_theme(role)
    DARK_MODE_ROLES.include?(role.to_s) ? "dark" : "light"
  end

  validates :email, uniqueness: { allow_nil: true }, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :email, presence: true, if: :secondary_profile?
  validates :name, presence: true
  validate :role_not_already_held_by_person

  def email_required?
    false
  end

  # The other logins belonging to the same human. Used to let a user move
  # between their roles without an admin in the middle.
  def sibling_profiles
    return [] if person.blank?

    person.profiles.where.not(id: id).to_a
  end

  def primary?
    person.present? && person.primary_profile&.id == id
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
    reminder_dismissed_at && reminder_dismissed_at >= Time.current.begin_of_day
  end

  # The persisted theme ("light"/"dark"), falling back to a role-based default
  # when the user hasn't picked one. This lets each profile (role) have its own
  # preferred theme.
  def effective_theme
    return theme_preference if %w[light dark].include?(theme_preference)

    User.role_default_theme(role)
  end

  private

  def normalize_email
    self.email = nil if email.blank?
  end

  # A profile is one login belonging to one human. Anyone without a person yet
  # gets one, so single-role accounts behave exactly as they did before.
  def ensure_person
    return if person.present?

    self.person = Person.new(name: name.presence || email.presence || "Unknown", phone_number: phone_number)
  end

  # A second role means a second login, and every login needs its own address
  # and password. A lone profile may still be created without an email.
  def secondary_profile?
    return false if person.blank? || !person.persisted?

    person.profiles.where.not(id: id).exists?
  end

  def role_not_already_held_by_person
    return if person.blank? || !person.persisted? || role.blank?

    return unless person.profiles.where(role: role).where.not(id: id).exists?

    errors.add(:role, "is already assigned to this person")
  end
end
