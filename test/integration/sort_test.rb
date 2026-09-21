require "test_helper"

class SortTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @user = User.find_or_create_by!(email: "test@test.com") do |u|
      u.name = "Test User"
      u.password = "password123"
      u.password_confirmation = "password123"
      u.role = :super_admin
    end
    @job = Job.find_or_create_by!(job_number: "JOB-00001", user: @user, customer_name: "Zoe", address: "1 Street", description: "Fix", status: :pending, priority: :maintenance, scheduled_date: Date.tomorrow, scheduled_time: Time.zone.parse("09:00"))
  end

  test "jobs index sorts by customer_name descending" do
    sign_in @user
    get jobs_path(sort: "customer_name", direction: "desc")
    assert_response :success
    body = response.body
    assert_includes body, "sortable-header sorted"
    assert_includes body, "direction=asc"
    assert_includes body, "sort=customer_name"
  end

  test "dashboard sorts by job_number ascending" do
    sign_in @user
    get dashboard_path(sort: "job_number", direction: "asc")
    assert_response :success
    body = response.body
    assert_includes body, "sortable-header sorted"
    assert_includes body, "direction=desc"
    assert_includes body, "sort=job_number"
  end

  test "dashboard jobs tab default is unsorted" do
    sign_in @user
    get dashboard_path(tab: "jobs")
    assert_response :success
    assert_includes response.body, "sortable-header"
  end

  test "mobile and tablet user agents use the desktop viewport" do
    sign_in @user

    get dashboard_path, headers: { "User-Agent" => "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/125.0.0.0 Mobile/15E148 Safari/604.1" }
    assert_response :success
    assert_includes response.body, 'name="viewport" content="width=1024"'
    assert_includes response.headers["Vary"], "User-Agent"

    get dashboard_path, headers: { "User-Agent" => "Mozilla/5.0 (Linux; Android 13; Pixel Tablet) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36" }
    assert_response :success
    assert_includes response.body, 'name="viewport" content="width=1024"'
  end

  test "desktop user agent keeps the responsive viewport" do
    sign_in @user
    get dashboard_path, headers: { "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36" }

    assert_response :success
    assert_includes response.body, 'name="viewport" content="width=device-width,initial-scale=1"'
  end
end
