class Claim < ApplicationRecord
  belongs_to :job

  enum :status, { pending: 0, submitted: 1, approved: 2, rejected: 3 }

  validates :amount, :claim_date, :status, presence: true
  validates :amount, numericality: { greater_than: 0 }

  delegate :customer_name, :job_number, to: :job
end
