class Person < ApplicationRecord
  has_many :profiles, class_name: "User", dependent: :destroy, inverse_of: :person

  validates :name, presence: true

  def roles
    profiles.map(&:role).compact
  end

  def role_list
    roles.map { |role| role.to_s.humanize }
  end

  def multi_role?
    profiles.size > 1
  end

  def primary_profile
    profiles.order(:id).first
  end
end
