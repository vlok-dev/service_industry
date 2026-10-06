class Job < ApplicationRecord
  belongs_to :user
  belongs_to :assigned_to, class_name: "User", optional: true
  belongs_to :client, optional: true
  has_many :purchase_orders, dependent: :destroy
  has_many :claims, dependent: :destroy
  has_many :digital_job_cards, dependent: :destroy
  has_many :quotes, dependent: :destroy

  # invoiced is its own status rather than a flag on completed, so a job is
  # never both. Values are the stored integers; invoiced: 5 keeps cancelled: 4
  # stable. Key order drives the status dropdown.
  enum :status, { pending: 0, scheduled: 1, in_progress: 2, completed: 3, invoiced: 5, cancelled: 4 }
  enum :priority, { maintenance: 0, project: 1 }

  validates :customer_name, :address, :description, :status, :priority, :user, presence: true
  validates :job_number, uniqueness: { allow_blank: true }
  validate :status_matches_invoice
  validates :scheduled_end_date,
            comparison: { greater_than_or_equal_to: :scheduled_date },
            if: -> { scheduled_date.present? && scheduled_end_date.present? }

  before_validation :assign_job_number, on: :create
  before_validation :populate_from_client, if: -> { client_id_changed? && client_id.present? }
  before_validation :sync_status_with_invoice
  before_validation :sync_priority_with_project, if: -> { priority.blank? || is_project_changed? }
  before_save :set_completed_at
  before_save :clear_whatsapp_sent_at_if_rescheduled
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
  # Outstanding means "the job is finished": every job whose status is
  # completed, i.e. awaiting an invoice. This is deliberately the same set as
  # the Completed filter so the two tabs can never disagree. Whether a job has
  # been costed is a per-job detail, exposed by costed?, not a different list.
  scope :outstanding, -> { where(status: :completed) }
  scope :ordered_by_date, -> { order(scheduled_date: :desc, scheduled_time: :desc, created_at: :desc) }

  def self.next_job_number
    last_job = Job.order(:id).last
    next_num = last_job&.id.to_i + 1
    "JOB-#{next_num.to_s.rjust(5, '0')}"
  end

  def display_status
    status.humanize
  end

  def display_label
    [ job_number, customer_name ].compact_blank.join(" - ")
  end

  def display_label_with_details
    parts = [ job_number, customer_name ].compact_blank
    parts << assigned_to&.name if assigned_to.present?
    parts << scheduled_date&.strftime("%d %b %Y") if scheduled_date.present?
    parts.join(" | ")
  end

  def display_status_key
    status.to_s
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

  # The invoice number decides whether a job is Completed or Invoiced, so the
  # two can never disagree no matter which path set the status.
  def status_matches_invoice
    if invoice_number.present? && !invoiced?
      errors.add(:base, "This job has invoice number #{invoice_number}, so its status must be Invoiced.")
    elsif invoice_number.blank? && invoiced?
      errors.add(:base, "An invoice number is required before a job can be Invoiced.")
    end
  end

  def set_completed_at
    return unless status_changed?

    if status.in?(%w[completed invoiced])
      # Keep the original timestamp when completed simply becomes invoiced.
      self.completed_at ||= Time.current
    else
      self.completed_at = nil
    end
  end

  # The invoice number is what makes a job invoiced, so the two never disagree.
  def sync_status_with_invoice
    return unless invoice_number_changed?

    if invoice_number.present?
      self.status = :invoiced
    elsif invoiced?
      # Invoice withdrawn - the work is still done, so it goes back to completed.
      self.status = :completed
    end
  end

  def sync_priority_with_project
    self.priority = is_project? ? :project : :maintenance
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

  private

  def clear_whatsapp_sent_at_if_rescheduled
    if scheduled_date_changed? || scheduled_time_changed? || assigned_to_id_changed?
      self.whatsapp_sent_at = nil
    end
  end
end
