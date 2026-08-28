class Job < ApplicationRecord
  belongs_to :user
  belongs_to :assigned_to, class_name: "User", optional: true

  enum :status, { pending: 0, scheduled: 1, in_progress: 2, completed: 3, cancelled: 4 }
  enum :priority, { low: 0, medium: 1, high: 2, emergency: 3 }

  validates :customer_name, :address, :description, :status, :priority, :user, presence: true
end
