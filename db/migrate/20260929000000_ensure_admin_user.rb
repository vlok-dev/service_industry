class EnsureAdminUser < ActiveRecord::Migration[8.1]
  def up
    user = User.find_or_initialize_by(email: "admin@industroplumbers.co.za")
    user.name = "Admin User"
    user.password = "password123"
    user.password_confirmation = "password123"
    user.role = :admin
    user.phone_number = "+27820000000"
    user.save!
  end

  def down
  end
end
