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
      priority: :maintenance,
      user: valid_user,
      scheduled_date: Date.new(2026, 9, 10),
      scheduled_time: Time.zone.parse("09:00")
    }
  end

  test "is valid with a unique scheduled time" do
    assert Job.new(base_attributes).valid?
  end

  test "is valid even when another job occupies the same date and time" do
    Job.create!(base_attributes.merge(customer_name: "Existing"))
    conflicting = Job.new(base_attributes.merge(customer_name: "New"))
    assert conflicting.valid?, conflicting.errors.full_messages.to_sentence
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

  test "completed job with an invoice displays as invoiced" do
    job = Job.create!(base_attributes.merge(status: :completed, invoice_number: "INV-00001"))

    assert job.invoiced?
    assert_equal "Invoiced", job.display_status
    assert_equal "invoiced", job.display_status_key
  end

  test "completed job without an invoice remains completed" do
    job = Job.create!(base_attributes.merge(status: :completed))

    assert_not job.invoiced?
    assert_equal "Completed", job.display_status
    assert_equal "completed", job.display_status_key
  end

  test "invoiced scope returns completed jobs with invoices" do
    invoiced_job = Job.create!(base_attributes.merge(status: :completed, invoice_number: "INV-00001"))
    Job.create!(base_attributes.merge(customer_name: "Uninvoiced", status: :completed))

    assert_includes Job.invoiced, invoiced_job
  end

  test "auto-generates a job number when the form submits an empty string" do
    job = Job.new(base_attributes.merge(customer_name: "New", job_number: ""))
    job.valid?
    assert job.job_number.present?, "job_number should be auto-generated, not blank"
    assert_match(/^JOB-/, job.job_number)
  end

  test "search is case-insensitive across customer_name, address, and job_number" do
    Job.create!(base_attributes.merge(customer_name: "BSp Builders", address: "274 Cape Road"))

    assert_includes Job.search("bsp"), Job.find_by!(customer_name: "BSp Builders")
    assert_includes Job.search("BSP"), Job.find_by!(customer_name: "BSp Builders")
    assert_includes Job.search("cape"), Job.find_by!(customer_name: "BSp Builders")
    assert_includes Job.search("CAPE"), Job.find_by!(customer_name: "BSp Builders")
    assert_includes Job.search("274"), Job.find_by!(customer_name: "BSp Builders")
    assert_empty Job.search("xyzxyz")
    assert_equal Job.count, Job.search("").count
  end
end
