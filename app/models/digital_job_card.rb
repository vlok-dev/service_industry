class DigitalJobCard < ApplicationRecord
  belongs_to :user
  belongs_to :client, optional: true
  belongs_to :job, optional: true
  has_many :materials, class_name: "DigitalJobCardMaterial", dependent: :destroy

  accepts_nested_attributes_for :materials, allow_destroy: true, reject_if: :all_blank

  validates :client_name, :address, :date, :time_start, :time_finish, :description, presence: true

  scope :recent, -> { order(date: :desc, time_start: :desc) }

  def material_lines
    materials.material_lines
  end

  def labor_lines
    materials.labor_lines
  end

  # Summed in Ruby so the figures always match the line items rendered
  # alongside them, whether or not the association is already loaded.
  def materials_total
    material_lines.sum(&:total_price)
  end

  def labor_total
    labor_lines.sum(&:total_price)
  end

  def grand_total
    materials_total + labor_total
  end
end
