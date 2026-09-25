class Job < ApplicationRecord
  belongs_to :user
  belongs_to :assigned_to, class_name: "User", optional: true
  belongs_to :client, optional: true
  has_many :purchase_orders, dependent: :destroy
  has_many :claims, dependent: :destroy
  has_many :digital_job_cards, dependent: :destroy

  enum :status, { pending: 0, scheduled: 1, in_progress: 2, completed: 3, cancelled: 4 }
  enum :priority, { maintenance: 0, project: 1 }

  validates :customer_name, :address, :description, :status, :priority, :user, presence: true
  validates :job_number, uniqueness: { allow_blank: true }
  validates :scheduled_end_date,
            comparison: { greater_than_or_equal_to: :scheduled_date },
            if: -> { scheduled_date.present? && scheduled_end_date.present? }

  before_validation :assign_job_number, on: :create
  before_validation :populate_from_client, if: -> { client_id_changed? && client_id.present? }
  before_save :set_completed_at_on_completion
  before_save :sync_status_with_invoice
  scope :search, ->(query) {
    return all if query.blank?
    sanitized = "%#{ActiveRecord::Base.sanitize_sql_like(query.to_s.strip)}%"
    where("LOWER(CAST(job_number AS TEXT)) LIKE LOWER(:q) OR LOWER(address) LIKE LOWER(:q) OR LOWER(CAST(invoice_number AS TEXT)) LIKE LOWER(:q) OR LOWER(customer_name) LIKE LOWER(:q)",
          q: sanitized)
  }
  scope :created_today, -> { where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day) }

  # A job occupies a given date if it starts on that date, or it is a multi-day
  # project whose scheduled range (scheduled_date..scheduled_end_date) covers it.
  # This keeps the Jobs tab filter, Print Jobs, and dashboard schedule view consistent.
  scope :on_date, ->(date) {
    where(
      "scheduled_date = :date OR (scheduled_end_date IS NOT NULL AND scheduled_date <= :date AND scheduled_end_date >= :date)",
      date: date
    )
  }
  scope :outstanding, -> { where.missing(:purchase_orders).where(status: [:completed]).where("invoice_number IS NULL OR invoice_number = ''") }
  scope :invoiced, -> { completed.where("invoice_number IS NOT NULL AND invoice_number <> ''") }

  def self.next_job_number
    last_job = Job.order(:id).last
    next_num = last_job&.id.to_i + 1
    "JOB-#{next_num.to_s.rjust(5, '0')}"
  end

  def completed_with_invoice?
    invoiced?
  end

  def invoiced?
    completed? && invoice_number.present?
  end

  def display_status
    invoiced? ? "Invoiced" : status.humanize
  end

  def display_status_key
    invoiced? ? "invoiced" : status.to_s
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

  private

  def assign_job_number
    self.job_number = Job.next_job_number if job_number.blank?
  end

  def set_completed_at_on_completion
    if status_changed? && completed?
      self.completed_at = Time.current
    elsif status_changed? && !completed?
      self.completed_at = nil
    end
  end

  def sync_status_with_invoice
    return unless invoice_number_changed?
    
    if invoice_number.present? && !completed?
      # Invoice added - mark as completed (invoiced)
      self.status = :completed
      self.completed_at = Time.current
    elsif invoice_number.blank? && completed? && invoice_number_was.present?
      # Invoice removed - revert to previous status if it was "invoiced" state
      # We need to determine what the previous status was before it became completed
      # For now, revert to scheduled as a sensible default for jobs that were invoiced
      self.status = :scheduled
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
