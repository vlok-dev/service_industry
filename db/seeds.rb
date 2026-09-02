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

plumber3 = User.find_or_create_by!(email: "thabo@industroplumbers.co.za") do |u|
  u.name = "Thabo Mokoena"
  u.password = "password123"
  u.password_confirmation = "password123"
  u.role = :plumber
  u.phone_number = "+27825551111"
end

plumber4 = User.find_or_create_by!(email: "sipho@industroplumbers.co.za") do |u|
  u.name = "Sipho Dlamini"
  u.password = "password123"
  u.password_confirmation = "password123"
  u.role = :plumber
  u.phone_number = "+27826662222"
end

plumber5 = User.find_or_create_by!(email: "lerato@industroplumbers.co.za") do |u|
  u.name = "Lerato Khumalo"
  u.password = "password123"
  u.password_confirmation = "password123"
  u.role = :plumber
  u.phone_number = "+27827773333"
end

plumber6 = User.find_or_create_by!(email: "peter@industroplumbers.co.za") do |u|
  u.name = "Peter Naidoo"
  u.password = "password123"
  u.password_confirmation = "password123"
  u.role = :plumber
  u.phone_number = "+27828884444"
end

plumber7 = User.find_or_create_by!(email: "james@industroplumbers.co.za") do |u|
  u.name = "James van der Merwe"
  u.password = "password123"
  u.password_confirmation = "password123"
  u.role = :plumber
  u.phone_number = "+27829995555"
end

plumber8 = User.find_or_create_by!(email: "thandi@industroplumbers.co.za") do |u|
  u.name = "Thandiwe Ndlovu"
  u.password = "password123"
  u.password_confirmation = "password123"
  u.role = :plumber
  u.phone_number = "+27821113333"
end

plumber9 = User.find_or_create_by!(email: "david@industroplumbers.co.za") do |u|
  u.name = "David Pillay"
  u.password = "password123"
  u.password_confirmation = "password123"
  u.role = :plumber
  u.phone_number = "+27822224444"
end

# Sample Jobs
Job.find_or_create_by!(customer_name: "John Smith", address: "123 Main Street, Johannesburg", description: "Leaking kitchen tap", status: :pending, priority: :medium, user: michelle)
Job.find_or_create_by!(customer_name: "Sarah Johnson", address: "456 Oak Avenue, Sandton", description: "Burst pipe in bathroom", status: :scheduled, priority: :high, user: michelle, scheduled_date: Date.tomorrow, scheduled_time: "09:00", assigned_to: plumber1)
Job.find_or_create_by!(customer_name: "Mike Williams", address: "789 Pine Road, Randburg", description: "Geyser installation", status: :in_progress, priority: :low, user: michelle, scheduled_date: Date.today, scheduled_time: "10:00", assigned_to: plumber2)