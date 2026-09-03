require "test_helper"

class JobTest < ActiveSupport::TestCase
  def valid_user
    User.find_or_create_by!(email: "plumber@test.com") do |u|
      u.name = "Plumber"
      u.password = "password123"
      u.role = :plumber
    end
  end

  def base_attributes
    {
      customer_name: "Customer",
      address: "123 Test St",
      description: "Fix leak",
      status: :scheduled,
      priority: :medium,
      user: valid_user,
      scheduled_date: Date.new(2026, 9, 10),
      scheduled_time: Time.zone.parse("09:00")
    }
  end

  test "is valid with a unique scheduled time" do
    assert Job.new(base_attributes).valid?
  end

  test "is invalid when another non-cancelled job occupies the same date and time" do
    Job.create!(base_attributes.merge(customer_name: "Existing"))
    conflicting = Job.new(base_attributes.merge(customer_name: "New"))
    assert_not conflicting.valid?
    assert_match(/already taken/, conflicting.errors[:scheduled_time].join)
  end

  test "is valid when scheduling the same time on a different day" do
    existing = Job.create!(base_attributes.merge(customer_name: "Existing"))
    other_day = Job.new(base_attributes.merge(customer_name: "Other day", scheduled_date: Date.new(2026, 9, 11), scheduled_time: existing.scheduled_time))
    assert other_day.valid?, other_day.errors.full_messages.to_sentence
  end

  test "is valid when scheduling a different time on the same day" do
    Job.create!(base_attributes.merge(customer_name: "Existing"))
    other_time = Job.new(base_attributes.merge(customer_name: "Other time", scheduled_time: Time.zone.parse("10:00")))
    assert other_time.valid?, other_time.errors.full_messages.to_sentence
  end

  test "is valid when the only conflict is a cancelled job at the same time" do
    Job.create!(base_attributes.merge(customer_name: "Cancelled", status: :cancelled))
    new_job = Job.new(base_attributes.merge(customer_name: "New"))
    assert new_job.valid?, new_job.errors.full_messages.to_sentence
  end

  test "does not conflict with itself when re-saving the same schedule" do
    job = Job.create!(base_attributes.merge(customer_name: "Existing"))
    job.scheduled_time = job.scheduled_time
    assert job.valid?, job.errors.full_messages.to_sentence
  end

  test "auto-generates a job number when left blank" do
    job = Job.new(base_attributes.merge(customer_name: "New", job_number: nil))
    job.valid?
    assert job.job_number.present?
    assert_match(/^JOB-/, job.job_number)
  end

  test "auto-generates a job number when the form submits an empty string" do
    job = Job.new(base_attributes.merge(customer_name: "New", job_number: ""))
    job.valid?
    assert job.job_number.present?, "job_number should be auto-generated, not blank"
    assert_match(/^JOB-/, job.job_number)
  end
end
