class Job < ApplicationRecord
  belongs_to :user
  belongs_to :assigned_to, class_name: "User", optional: true

  enum :status, { pending: 0, scheduled: 1, in_progress: 2, completed: 3, cancelled: 4 }
  enum :priority, { low: 0, medium: 1, high: 2, emergency: 3 }

  validates :customer_name, :address, :description, :status, :priority, :user, presence: true
  validates :job_number, uniqueness: { allow_blank: true }

  before_validation :assign_job_number, on: :create
  before_save :assign_invoice_number_on_completion
  scope :search, ->(query) {
    return all if query.blank?
    where("job_number LIKE ? OR address LIKE ? OR invoice_number LIKE ?", "%#{query}%", "%#{query}%", "%#{query}%")
  }

  def self.next_job_number
    last_job = Job.order(:id).last
    next_num = last_job&.id.to_i + 1
    "JOB-#{next_num.to_s.rjust(5, '0')}"
  end

  def self.next_invoice_number
    last_job = Job.where.not(invoice_number: nil).order(:invoice_number).last
    if last_job&.invoice_number
      num = last_job.invoice_number.gsub(/\D/, "").to_i + 1
    else
      num = 1
    end
    "INV-#{num.to_s.rjust(5, '0')}"
  end

  def completed_with_invoice?
    completed? && invoice_number.present?
  end

  private

  def assign_job_number
    self.job_number ||= Job.next_job_number
  end

  def assign_invoice_number_on_completion
    if status_changed? && completed? && invoice_number.blank?
      self.invoice_number = Job.next_invoice_number
    end
  end
end
