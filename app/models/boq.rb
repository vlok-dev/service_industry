class Boq < ApplicationRecord
  belongs_to :job, optional: true
  belongs_to :created_by, class_name: "User", optional: true

  has_many :items, -> { order(:position, :id) }, class_name: "BoqItem", dependent: :destroy
  accepts_nested_attributes_for :items, allow_destroy: true,
    reject_if: ->(attributes) { attributes["description"].blank? && attributes["row_type"] != "spacer" }

  validates :project_title, presence: true

  before_validation :assign_sheet_name
  before_validation :assign_boq_number, on: :create

  DEFAULT_CLAIM_LABELS = [ "1st claim", "2nd claim", "3rd claim", "4th claim" ].freeze

  def self.next_boq_number
    last = Boq.order(:id).last
    next_num = last&.id.to_i + 1
    "BOQ-#{next_num.to_s.rjust(5, '0')}"
  end

  def display_name
    project_title.to_s
  end

  def job_label
    job&.display_label.presence || "Not linked to a job"
  end

  def sheet_name
    value = sheet_name_override.presence || derived_sheet_name
    value.to_s.upcase.gsub(/[\[\]:*?\/\\]/, " ").strip[0, 31].presence || "BOQ"
  end

  def workbook_title
    project_title.to_s.upcase
  end

  def claim_entries
    labels = [ claim_1_label, claim_2_label, claim_3_label, claim_4_label ]
    amounts = [ claim_1_amount, claim_2_amount, claim_3_amount, nil ]

    labels.each_with_index.map do |label, index|
      {
        label: label.presence || DEFAULT_CLAIM_LABELS[index],
        amount: amounts[index]
      }
    end
  end

  def total_value
    items.select { |item| item.row_type == "item" }.sum do |item|
      (item.claimed_qty.to_f * item.rate.to_f).round(2)
    end
  end

  def balance_value
    claimed = claim_entries.reject { |claim| claim[:amount].nil? }.sum { |claim| claim[:amount].to_f }
    (total_value - claimed).round(2)
  end

  def workbook_rows
    items.map do |item|
      {
        kind: item.row_type.to_sym,
        page: item.page,
        item_code: item.item_code,
        description: item.description,
        unit: item.unit,
        bill_qty: item.bill_qty,
        claimed_qty: item.claimed_qty,
        rate: item.rate,
        total_formula: item.total_formula?
      }
    end
  end

  def workbook_builder
    BoqWorkbookBuilder.new(
      sheet_name: sheet_name,
      title: workbook_title,
      rows: workbook_rows,
      claims: claim_entries
    )
  end

  def workbook_blob
    workbook_builder.to_blob
  end

  def download_filename
    title_part = project_title.to_s.strip.gsub(/\s+/, "_")
    claim_part = claim_entries.last[:label].to_s.split("-").first.to_s.strip.gsub(/\s+/, "_")
    claim_part = "claim" if claim_part.empty?
    "BOQ_-_#{title_part}_-_#{claim_part}.xlsx"
  end

  private

  def sheet_name_override
    self[:sheet_name]
  end

  def derived_sheet_name
    project_title.to_s.split(/[\s\-_]+/).last.to_s
  end

  def assign_sheet_name
    self.sheet_name = sheet_name if sheet_name_override.blank?
  end

  def assign_boq_number
    self.boq_number ||= Boq.next_boq_number
  end
end
