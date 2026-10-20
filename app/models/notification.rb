class Notification < ApplicationRecord
  has_many :notification_dismissals, dependent: :destroy
  validates :title, :show_from, presence: true
  scope :due, -> { where("show_from LIKE ?", "%#{Date.today}%") }
end

class NotificationDismissal < ApplicationRecord
  belongs_to :user
  belongs_to :notification
end
