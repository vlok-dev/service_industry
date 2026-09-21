class PlannerEntry < ApplicationRecord
  belongs_to :assigned_to, class_name: "User"
  belongs_to :created_by, class_name: "User", optional: true

  enum :category, {
    medical: "medical",
    car_service: "car_service",
    meeting: "meeting",
    admin: "admin",
    training: "training",
    other: "other"
  }

  enum :status, {
    to_do: 0,
    in_progress: 1,
    done: 2,
    cancelled: 3
  }

  validates :title, :entry_date, :created_by, :assigned_to, presence: true

  after_commit :schedule_whatsapp_reminder, on: [:create, :update], if: :should_schedule_whatsapp?

  scope :upcoming, -> { where("entry_date >= ?", Date.today).order(:entry_date, :entry_time) }
  scope :past, -> { where("entry_date < ?", Date.today).order(:entry_date, :entry_time) }
  scope :reminders_due, ->(user = nil) {
    base = where("entry_date BETWEEN ? AND ?", Date.today, Date.today + 3.days)
           .where.not(status: :done).where.not(status: :cancelled)
           .order(:entry_date, :entry_time)
    if user
      base.where("assigned_to_id IS NULL OR assigned_to_id = ?", user.id)
    else
      base
    end
  }
  scope :search, ->(query) {
    return all if query.blank?
    sanitized = "%#{ActiveRecord::Base.sanitize_sql_like(query.to_s.strip)}%"
    where("LOWER(title) LIKE LOWER(:q) OR LOWER(description) LIKE LOWER(:q) OR LOWER(notes) LIKE LOWER(:q)", q: sanitized)
  }

  def category_color
    case category
    when "medical" then "#dc2626"
    when "car_service" then "#2563eb"
    when "meeting" then "#7c3aed"
    when "admin" then "#6b7280"
    when "training" then "#059669"
    else "#d97706"
    end
  end

  def category_icon
    case category
    when "medical" then "🏥"
    when "car_service" then "🚗"
    when "meeting" then "👥"
    when "admin" then "📋"
    when "training" then "📚"
    else "📌"
    end
  end

  private

  def should_schedule_whatsapp?
    assigned_to_id.present? && entry_date.present? && entry_time.present? && assigned_to&.phone_number.present?
  end

  def schedule_whatsapp_reminder
    # Calculate when to send reminder (1 day before at 9:00 AM)
    reminder_time = entry_date - 1.day
    reminder_time = reminder_time.in_time_zone.change(hour: 9, min: 0)

    # Only schedule if reminder time is in the future
    if reminder_time > Time.current
      PlannerEntryWhatsappReminderJob.set(wait_until: reminder_time).perform_later(id)
    end
  end
end