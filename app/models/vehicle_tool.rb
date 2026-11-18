class VehicleTool < ApplicationRecord
  belongs_to :vehicle

  validates :name, presence: true
end
