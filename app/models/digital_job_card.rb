class DigitalJobCard < ApplicationRecord
  belongs_to :user
  belongs_to :client, optional: true
  belongs_to :job, optional: true
  has_many :materials, class_name: "DigitalJobCardMaterial", dependent: :destroy

  accepts_nested_attributes_for :materials, allow_destroy: true, reject_if: :all_blank

  validates :client_name, :address, :date, :time_start, :time_finish, :description, presence: true

  scope :recent, -> { order(date: :desc, time_start: :desc) }
end
