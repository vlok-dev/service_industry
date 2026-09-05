class Supplier < ApplicationRecord
  has_many :purchase_orders, dependent: :nullify

  validates :name, presence: true
  validates :email, format: { with: /\A[^@\s]+@[^@\s]+\z/, message: "must look like an email address" }, allow_blank: true
  validates :phone, format: { with: /\A[0-9+\s\-().]+\z/, message: "can only contain numbers, spaces and + - () ." }, allow_blank: true

  def self.ordered
    order(:name)
  end
end
