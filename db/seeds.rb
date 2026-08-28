# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here is idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Users
michelle = User.find_or_create_by!(email: "michelle@industroplumbers.co.za") do |u|
  u.name = "Michelle"
  u.password = "password123"
  u.password_confirmation = "password123"
  u.role = :super_admin
  u.phone_number = "+27821234567"
end

michael = User.find_or_create_by!(email: "michael@industroplumbers.co.za") do |u|
  u.name = "Michael"
  u.password = "password123"
  u.password_confirmation = "password123"
  u.role = :scheduler
  u.phone_number = "+27827654321"
end

lee_anne = User.find_or_create_by!(email: "leeanne@industroplumbers.co.za") do |u|
  u.name = "Lee Anne"
  u.password = "password123"
  u.password_confirmation = "password123"
  u.role = :reporter
  u.phone_number = "+27829876543"
end

admin = User.find_or_create_by!(email: "admin@industroplumbers.co.za") do |u|
  u.name = "Admin User"
  u.password = "password123"
  u.password_confirmation = "password123"
  u.role = :admin
  u.phone_number = "+27820000000"
end

plumber1 = User.find_or_create_by!(email: "john@industroplumbers.co.za") do |u|
  u.name = "John Plumber"
  u.password = "password123"
  u.password_confirmation = "password123"
  u.role = :plumber
  u.phone_number = "+27821112222"
end

plumber2 = User.find_or_create_by!(email: "jane@industroplumbers.co.za") do |u|
  u.name = "Jane Plumber"
  u.password = "password123"
  u.password_confirmation = "password123"
  u.role = :plumber
  u.phone_number = "+27823334444"
end

# Sample Jobs
Job.find_or_create_by!(customer_name: "John Smith", address: "123 Main Street, Johannesburg", description: "Leaking kitchen tap", status: :pending, priority: :medium, user: michelle)
Job.find_or_create_by!(customer_name: "Sarah Johnson", address: "456 Oak Avenue, Sandton", description: "Burst pipe in bathroom", status: :scheduled, priority: :high, user: michelle, scheduled_date: Date.tomorrow, scheduled_time: "09:00", assigned_to: plumber1)
Job.find_or_create_by!(customer_name: "Mike Williams", address: "789 Pine Road, Randburg", description: "Geyser installation", status: :in_progress, priority: :low, user: michelle, scheduled_date: Date.today, scheduled_time: "10:00", assigned_to: plumber2)