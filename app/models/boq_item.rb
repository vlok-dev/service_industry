class BoqItem < ApplicationRecord
  belongs_to :boq

  enum :row_type, { heading: "heading", item: "item", spacer: "spacer" }, default: "item"

  before_validation :assign_position

  def line_total
    (claimed_qty.to_f * rate.to_f).round(2)
  end

  def blank_row?
    spacer?
  end

  private

  def assign_position
    self.position ||= (boq&.items&.maximum(:position).to_i + 1) if boq_id
  end
end
