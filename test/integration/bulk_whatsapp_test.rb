require "test_helper"

class BulkWhatsappTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @scheduler = User.create!(
      name: "Scheduler", email: "scheduler-bulk@test.com",
      password: "password123", role: :scheduler
    )
    @plumber = User.create!(
      name: "Sipho Ndlovu", email: "plumber-bulk@test.com",
      password: "password123", role: :plumber, phone_number: "082 555 0134"
    )
    @no_number = User.create!(
      name: "No Number", email: "nonumber-bulk@test.com",
      password: "password123", role: :plumber
    )
    @date = Date.new(2026, 10, 5)
    sign_in @scheduler
  end

  def create_job(overrides = {})
    Job.create!({
      customer_name: "Thabo Mokoena",
      address: "14 Protea Road",
      description: "Burst pipe",
      status: :scheduled,
      priority: :maintenance,
      user: @scheduler,
      assigned_to: @plumber,
      scheduled_date: @date,
      scheduled_time: Time.zone.parse("09:00")
    }.merge(overrides))
  end

  # The queue is embedded in the page as JSON for the client-side stepper, so
  # its membership is asserted from the rendered body rather than via assigns.
  def queued_customer_names
    JSON.parse(response.body[/<script type="application\/json" id="bulk-queue-data">(.*?)<\/script>/m, 1])
      .map { |job| job["customer"] }
  end

  test "queue lists only unsent jobs that have a plumber number" do
    queued = create_job(customer_name: "Ready To Send")
    create_job(customer_name: "Already Sent", scheduled_time: Time.zone.parse("10:00"),
               whatsapp_sent_at: Time.current)
    create_job(customer_name: "No Number", scheduled_time: Time.zone.parse("11:00"),
               assigned_to: @no_number)

    get bulk_whatsapp_jobs_path(scheduled_date: @date.iso8601)

    assert_response :success
    assert_equal ["Ready To Send"], queued_customer_names
    assert queued.id
  end

  test "queue reports skipped jobs with a reason" do
    create_job(customer_name: "Ready To Send")
    create_job(customer_name: "Already Sent", scheduled_time: Time.zone.parse("10:00"),
               whatsapp_sent_at: Time.current)
    create_job(customer_name: "No Number", scheduled_time: Time.zone.parse("11:00"),
               assigned_to: @no_number)

    get bulk_whatsapp_jobs_path(scheduled_date: @date.iso8601)

    assert_response :success
    assert_equal ["Ready To Send"], queued_customer_names
    assert_includes response.body, "Already Sent"
    assert_includes response.body, "No plumber phone number"
    assert_includes response.body, "Already sent"
  end

  test "queue is empty when the day has nothing to send" do
    create_job(whatsapp_sent_at: Time.current)

    get bulk_whatsapp_jobs_path(scheduled_date: @date.iso8601)

    assert_response :success
    assert_empty queued_customer_names
  end

  test "queue ignores jobs from another day" do
    create_job(scheduled_date: @date - 1.day)

    get bulk_whatsapp_jobs_path(scheduled_date: @date.iso8601)

    assert_response :success
    assert_empty queued_customer_names
  end

  # Each send stamps its own job, so an interrupted bulk run never marks the
  # messages it never reached as sent.
  test "confirm_whatsapp stamps one job and returns its wa.me link" do
    first = create_job
    second = create_job(customer_name: "Second", scheduled_time: Time.zone.parse("10:00"))

    post confirm_whatsapp_job_path(first), as: :json

    assert_response :success
    assert first.reload.whatsapp_sent_at.present?
    assert_nil second.reload.whatsapp_sent_at
    assert_match %r{\Ahttps://wa\.me/27825550134\?text=}, JSON.parse(response.body)["whatsapp_url"]
  end

  test "confirm_whatsapp does not stamp when the plumber has no number" do
    job = create_job(assigned_to: @no_number)

    post confirm_whatsapp_job_path(job), as: :json

    assert_response :unprocessable_entity
    assert_nil job.reload.whatsapp_sent_at
  end

  test "plumber cannot reach the bulk queue" do
    plumber = User.create!(
      name: "Other Plumber", email: "other-bulk@test.com",
      password: "password123", role: :plumber, phone_number: "082 555 9999"
    )
    sign_in plumber

    get bulk_whatsapp_jobs_path(scheduled_date: @date.iso8601)

    assert_response :redirect
  end
end
