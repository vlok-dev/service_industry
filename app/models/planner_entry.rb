class PlannerEntry < ApplicationRecord
  belongs_to :assigned_to, class_name: "User", optional: true
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

  validates :title, :entry_date, :created_by, presence: true

  scope :upcoming, -> { where("entry_date >= ?", Date.today).order(:entry_date, :entry_time) }
  scope :past, -> { where("entry_date < ?", Date.today).order(:entry_date, :entry_time) }
  scope :search, ->(query) {
    return all if query.blank?
    sanitized = "%#{ActiveRecord::Base.sanitize_sql_like(query.to_s.strip)}%"
    where("title LIKE :q OR description LIKE :q OR notes LIKE :q", q: sanitized)
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
end