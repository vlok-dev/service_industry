class Report < ApplicationRecord
  belongs_to :user

  enum :category, { bug: 0, suggestion: 1 }
  enum :status, { open: 0, in_progress: 1, resolved: 2 }

  validates :title, presence: true
  validates :category, presence: true
end
