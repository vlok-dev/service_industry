class Retention < ApplicationRecord
  belongs_to :client, optional: true

  validates :project_name, presence: true
  validates :client_name, presence: true
  validates :date_held, presence: true
  validates :release_date, presence: true
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(release_date: :asc, created_at: :desc) }
  scope :upcoming_release, -> { where("release_date <= ?", 30.days.from_now).where("release_date >= ?", Date.current) }
  scope :overdue, -> { where("release_date < ?", Date.current) }

  def client_display
    client&.name || client_name
  end
end
