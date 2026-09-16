require "test_helper"

class WhatsAppServiceTest < ActiveSupport::TestCase
  def build_job(scheduled_time)
    Job.new(
      customer_name: "John Doe",
      address: "274 Cape Road",
      description: "Fix leak",
      scheduled_time: scheduled_time
    )
  end

  test "build_message includes 'Tomorrow at <time>' when scheduled_time is present" do
    job = build_job(Time.zone.parse("09:00"))
    message = WhatsAppService.build_message(job)
    assert_includes message, "Tomorrow at 09:00 AM"
  end

  test "build_message shows 'Tomorrow' without time when scheduled_time is nil" do
    job = build_job(nil)
    message = WhatsAppService.build_message(job)
    assert_includes message, "Tomorrow"
    assert_not_includes message, "Tomorrow at"
    assert_not_includes message, "@"
  end
end
