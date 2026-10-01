require "test_helper"

class WhatsappHelperTest < ActionView::TestCase
  tests WhatsappHelper

  def build_job(assigned_to: nil, scheduled_date: Date.new(2026, 10, 5), scheduled_time: nil)
    Job.new(
      customer_name: "Thabo Mokoena",
      address: "14 Protea Road, Randburg",
      description: "Burst pipe",
      is_project: false,
      scheduled_date: scheduled_date,
      scheduled_time: scheduled_time
    ).tap { |job| job.assigned_to = assigned_to if assigned_to }
  end

  def build_user(phone_number)
    User.new(name: "Sipho Ndlovu", phone_number: phone_number, role: :plumber)
  end

  # wa.me needs a bare international number. A locally-stored 082... number is
  # useless to wa.me unless the 27 country code is prefixed.
  test "whatsapp_phone_digits converts a local number to international" do
    assert_equal "27825550134", whatsapp_phone_digits("082 555 0134")
    assert_equal "27825550134", whatsapp_phone_digits("0825550134")
    assert_equal "27825550134", whatsapp_phone_digits("+27 82 555 0134")
  end

  test "whatsapp_phone_digits leaves an already international number alone" do
    assert_equal "27825550134", whatsapp_phone_digits("27825550134")
    assert_equal "27825550134", whatsapp_phone_digits("+27 82 555 0134")
  end

  test "whatsapp_phone_digits returns nil for a blank number" do
    assert_nil whatsapp_phone_digits(nil)
    assert_nil whatsapp_phone_digits("")
    assert_nil whatsapp_phone_digits("not a number")
  end

  test "job_whatsapp_url is nil when the plumber has no number" do
    assert_nil job_whatsapp_url(build_job(assigned_to: build_user(nil)))
  end

  test "job_whatsapp_url targets the plumber number with the message pre-filled" do
    url = job_whatsapp_url(build_job(assigned_to: build_user("082 555 0134")))

    assert url.start_with?("https://wa.me/27825550134?text="),
      "expected a wa.me link for the plumber, got #{url}"
    assert_includes CGI.unescape(url), "Thabo Mokoena"
    assert_includes CGI.unescape(url), "14 Protea Road, Randburg"
  end

  test "job_whatsapp_message names the job type and carries the schedule" do
    job = build_job(
      assigned_to: build_user("0825550134"),
      scheduled_time: Time.zone.parse("09:00")
    )
    message = job_whatsapp_message(job)

    assert_includes message, "Car Service"
    assert_includes message, "Date: 05 October 2026"
    assert_includes message, "Time: 09:00 AM"
  end

  test "job_whatsapp_message says Project for a project job" do
    job = build_job(assigned_to: build_user("0825550134"))
    job.is_project = true

    assert_includes job_whatsapp_message(job), "Project"
  end

  # A job is only queueable when it still needs sending and has somewhere to go.
  test "job_whatsapp_sendable? requires an unsent job with a plumber number" do
    assert job_whatsapp_sendable?(build_job(assigned_to: build_user("0825550134")))
    assert_not job_whatsapp_sendable?(build_job(assigned_to: build_user(nil)))
  end

  test "job_whatsapp_sendable? is false once whatsapp_sent_at is set" do
    job = build_job(assigned_to: build_user("0825550134"))
    job.whatsapp_sent_at = Time.current

    assert_not job_whatsapp_sendable?(job), "an already-sent job must not be queued again"
  end

  test "whatsapp_sent_at_display is nil when nothing was sent" do
    assert_nil whatsapp_sent_at_display(build_job)
  end

  test "whatsapp_sent_at_display renders the stored timestamp" do
    job = build_job
    job.whatsapp_sent_at = Time.utc(2026, 10, 5, 7, 0)

    assert_equal "05 Oct 2026 at 09:00 AM", whatsapp_sent_at_display(job)
  end
end
