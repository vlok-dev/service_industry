class Job < ApplicationRecord
  belongs_to :user
  belongs_to :assigned_to, class_name: "User", optional: true
  belongs_to :client, optional: true
  has_many :purchase_orders, dependent: :destroy
  has_many :claims, dependent: :destroy

  enum :status, { pending: 0, scheduled: 1, in_progress: 2, completed: 3, cancelled: 4 }
  enum :priority, { maintenance: 0, project: 1 }

  validates :customer_name, :address, :description, :status, :priority, :user, presence: true
  validates :job_number, uniqueness: { allow_blank: true }
  validate :no_conflicting_scheduled_time, if: -> { scheduled_date.present? && scheduled_time.present? }
  validates :scheduled_end_date,
            comparison: { greater_than_or_equal_to: :scheduled_date },
            if: -> { scheduled_date.present? && scheduled_end_date.present? }

  before_validation :assign_job_number, on: :create
  before_validation :populate_from_client, if: -> { client_id_changed? && client_id.present? }
  before_save :assign_invoice_number_on_completion
  before_save :set_completed_at_on_completion
  scope :search, ->(query) {
    return all if query.blank?
    sanitized = "%#{ActiveRecord::Base.sanitize_sql_like(query.to_s.strip)}%"
    where("CAST(job_number AS TEXT) LIKE :q OR address LIKE :q OR CAST(invoice_number AS TEXT) LIKE :q OR customer_name LIKE :q",
          q: sanitized)
  }
  scope :created_today, -> { where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day) }
  scope :outstanding, -> { created_today.where.missing(:purchase_orders) }

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

  def costed?
    purchase_orders.exists?
  end

  def multi_day?
    scheduled_end_date.present? && scheduled_end_date > scheduled_date
  end

  def add_extra_day!
    self.scheduled_end_date = (scheduled_end_date || scheduled_date) + 1.day
    save
  end

  def no_conflicting_scheduled_time
    conflicts = Job
      .where(scheduled_date: scheduled_date, scheduled_time: scheduled_time)
      .where.not(status: :cancelled)
    conflicts = conflicts.where.not(id: id) if persisted?
    if assigned_to_id.present?
      conflicts = conflicts.where(assigned_to_id: assigned_to_id)
    end
    if conflicts.exists?
      errors.add(:scheduled_time, "is already taken. Another job is already scheduled for #{scheduled_date.strftime('%Y-%m-%d')} at #{scheduled_time.strftime('%H:%M')}.")
    end
  end

  private

  def assign_job_number
    self.job_number = Job.next_job_number if job_number.blank?
  end

  def assign_invoice_number_on_completion
    if status_changed? && completed? && invoice_number.blank?
      self.invoice_number = Job.next_invoice_number
    end
  end

  def set_completed_at_on_completion
    if status_changed? && completed?
      self.completed_at = Time.current
    elsif status_changed? && !completed?
      self.completed_at = nil
    end
  end

  def populate_from_client
    return unless client.present?
    self.customer_code = client.customer_code if customer_code.blank?
    self.customer_name = client.name if customer_name.blank?
    self.contact_person = client.contact_person if contact_person.blank?
    self.email = client.email if email.blank?
    self.contact_number = (client.primary_contact_mobile.presence || client.phone_number) if contact_number.blank?
    self.address = (client.delivery_address.presence || client.address) if address.blank?
    self.postal_address = (client.postal_address.presence || client.delivery_address) if postal_address.blank?
  end
end
