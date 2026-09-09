require "test_helper"

class ChecklistFeaturesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @super_admin = User.find_or_create_by!(email: "superadmin@test.com") do |u|
      u.name = "Michelle"
      u.password = "password123"
      u.password_confirmation = "password123"
      u.role = :super_admin
    end

    @scheduler = User.find_or_create_by!(email: "scheduler@test.com") do |u|
      u.name = "Michael"
      u.password = "password123"
      u.password_confirmation = "password123"
      u.role = :scheduler
    end

    @accountant = User.find_or_create_by!(email: "accountant@test.com") do |u|
      u.name = "Juanie Accounts"
      u.password = "password123"
      u.password_confirmation = "password123"
      u.role = :accountant
    end

    @reporter = User.find_or_create_by!(email: "reporter@test.com") do |u|
      u.name = "Lee Anne"
      u.password = "password123"
      u.password_confirmation = "password123"
      u.role = :reporter
    end

    @plumber = User.find_or_create_by!(email: "plumber@test.com") do |u|
      u.name = "Plumber"
      u.password = "password123"
      u.password_confirmation = "password123"
      u.role = :plumber
    end
  end

  def create_job!(attrs = {})
    defaults = {
      customer_name: "Customer",
      address: "123 Test St",
      description: "Fix leak",
      status: :scheduled,
      priority: :maintenance,
      user: @super_admin,
      scheduled_date: Date.tomorrow,
      scheduled_time: Time.zone.parse("09:00"),
      is_project: false
    }
    defaults.merge!(attrs)
    Job.create!(defaults)
  end

  # --- Item 1: Accountant can close a job ---

  test "accountant closes pending job marks completed with invoice" do
    sign_in @accountant
    job = create_job!(status: :pending, scheduled_date: Date.today, scheduled_time: Time.zone.parse("09:00"))

    patch close_job_path(job)

    assert_response :redirect
    job.reload
    assert job.completed?, "Job should be marked as completed"
    assert job.invoice_number.present?, "Job should have an auto-generated invoice number"
    assert job.completed_at.present?, "Job should have completed_at set"
  end

  test "accountant closes scheduled job marks completed with invoice" do
    sign_in @accountant
    job = create_job!(status: :scheduled, scheduled_time: Time.zone.parse("10:00"))

    patch close_job_path(job)

    assert_response :redirect
    job.reload
    assert job.completed?
    assert job.invoice_number.present?
  end

  test "accountant closes in_progress job marks completed with invoice" do
    sign_in @accountant
    job = create_job!(status: :in_progress, scheduled_time: Time.zone.parse("11:00"))

    patch close_job_path(job)

    assert_response :redirect
    job.reload
    assert job.completed?
    assert job.invoice_number.present?
  end

  test "closing an already completed job does not raise and stays completed" do
    sign_in @accountant
    job = create_job!(status: :completed, scheduled_time: Time.zone.parse("12:00"))
    invoice = job.invoice_number

    patch close_job_path(job)

    assert_response :redirect
    job.reload
    assert job.completed?
    assert_equal invoice, job.invoice_number
  end

  test "scheduler cannot close a job" do
    sign_in @scheduler
    job = create_job!(status: :pending, scheduled_time: Time.zone.parse("13:00"))

    patch close_job_path(job)

    assert_response :redirect
    assert_equal "pending", job.reload.status
  end

  test "plumber cannot close a job" do
    sign_in @plumber
    job = create_job!(status: :pending, scheduled_time: Time.zone.parse("14:00"))

    patch close_job_path(job)

    assert_response :redirect
    assert_equal "pending", job.reload.status
  end

  test "close button appears on job show page for accountant" do
    sign_in @accountant
    job = create_job!(status: :scheduled, scheduled_time: Time.zone.parse("15:00"))

    get job_path(job)
    assert_response :success
    assert_includes response.body, "Close Job"
  end

  test "close button does not appear for completed job" do
    sign_in @accountant
    job = create_job!(status: :completed, scheduled_time: Time.zone.parse("16:00"))

    get job_path(job)
    assert_response :success
    assert_not_includes response.body, "Close Job"
  end

  test "super_admin can close a job" do
    sign_in @super_admin
    job = create_job!(status: :pending, scheduled_time: Time.zone.parse("17:00"))

    patch close_job_path(job)

    assert_response :redirect
    job.reload
    assert job.completed?
  end

  # --- Item 2: Scheduler dashboard has same stat cards as accountant ---

  test "scheduler dashboard shows same kpi strip as super_admin" do
    sign_in @scheduler

    create_job!(customer_name: "Pending Job", status: :pending, scheduled_time: Time.zone.parse("09:00"))
    create_job!(customer_name: "Scheduled Job", status: :scheduled, scheduled_time: Time.zone.parse("10:00"))
    create_job!(customer_name: "InProgress Job", status: :in_progress, scheduled_time: Time.zone.parse("11:00"))
    create_job!(customer_name: "Done Job", status: :completed, scheduled_time: Time.zone.parse("12:00"))

    get dashboard_path

    assert_response :success
    body = response.body
    assert_includes body, "kpi-strip"
    assert_includes body, "kpi-pending"
    assert_includes body, "kpi-scheduled"
    assert_includes body, "kpi-progress"
    assert_includes body, "kpi-completed"
    assert_includes body, "Pending"
    assert_includes body, "Scheduled"
    assert_includes body, "In Progress"
    assert_includes body, "Completed"
    assert_includes body, "Job Pipeline"
  end

  test "accountant dashboard shows stat cards" do
    sign_in @accountant

    get dashboard_path
    assert_response :success
    assert_includes response.body, "stats-grid"
    assert_includes response.body, "stat-card"
  end

  # --- Item 3: Outstanding job cards ---

  test "jobs created today appear as outstanding" do
    job = create_job!(status: :pending, scheduled_time: Time.zone.parse("09:00"))
    assert_includes Job.outstanding, job
  end

  test "jobs with purchase orders are not outstanding" do
    job = create_job!(status: :pending, scheduled_time: Time.zone.parse("10:00"))
    job.purchase_orders.create!(
      supplier_name: "Test Supplier",
      order_date: Date.today,
      created_by: @reporter
    )
    assert_not_includes Job.outstanding, job
  end

  test "jobs created on a previous day are not outstanding" do
    job = create_job!(status: :pending, scheduled_time: Time.zone.parse("11:00"))
    job.update_column(:created_at, 2.days.ago)
    assert_not_includes Job.outstanding, job
  end

  test "outstanding jobs card appears on accountant dashboard" do
    sign_in @accountant
    create_job!(status: :scheduled, scheduled_time: Time.zone.parse("12:00"))

    get dashboard_path
    assert_response :success
    assert_includes response.body, "Outstanding Job Cards"
  end

  test "outstanding jobs card appears on scheduler dashboard" do
    sign_in @scheduler
    create_job!(status: :scheduled, scheduled_time: Time.zone.parse("13:00"))

    get dashboard_path
    assert_response :success
    assert_includes response.body, "Outstanding Job Cards"
  end

  test "outstanding jobs card appears on reporter dashboard" do
    sign_in @reporter
    create_job!(status: :scheduled, scheduled_time: Time.zone.parse("14:00"))

    get dashboard_path
    assert_response :success
    assert_includes response.body, "Outstanding Job Cards"
  end

  test "reporter sees Cost Add PO link for outstanding job without purchase order" do
    sign_in @reporter
    create_job!(status: :scheduled, scheduled_time: Time.zone.parse("15:00"))

    get dashboard_path
    assert_response :success
    assert_includes response.body, "Cost (Add PO)"
  end

  test "jobs index has Outstanding filter link" do
    sign_in @reporter
    get jobs_path
    assert_response :success
    assert_includes response.body, "Outstanding"
    assert_includes response.body, "filter=outstanding"
  end

  test "outstanding filter shows only jobs created today without purchase orders" do
    sign_in @reporter
    outstanding_job = create_job!(status: :pending, scheduled_time: Time.zone.parse("16:00"))

    get jobs_path(filter: "outstanding")
    assert_response :success
    assert_includes response.body, outstanding_job.customer_name
  end

  test "outstanding jobs are no longer outstanding when purchase order is added" do
    sign_in @reporter
    job = create_job!(status: :pending, scheduled_time: Time.zone.parse("17:00"))

    assert_includes Job.outstanding, job

    job.purchase_orders.create!(
      supplier_name: "ACME Supplies",
      order_date: Date.today,
      created_by: @reporter
    )

    assert_not_includes Job.outstanding, job
    assert job.costed?
  end

  # --- Feature: Clients ---

  test "super_admin can create a client" do
    sign_in @super_admin

    get new_client_path
    assert_response :success

    post clients_path, params: { client: { first_name: "Test", last_name: "User", company: "Test Company", phone_number: "011 000 0000", address: "123 Test Ave", email: "jane@test.com" } }
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert(Client.exists?(name: "Test Company"))
  end

  test "accountant can view clients index" do
    sign_in @accountant
    get clients_path
    assert_response :success
  end

  test "non-admin cannot create or edit clients" do
    sign_in @reporter
    get new_client_path
    assert_response :redirect
    assert_equal "You are not authorized to manage clients.", flash[:alert]
  end

  test "selecting a client populates customer name and address via callback" do
    client = Client.create!(first_name: "Saved Client", address: "456 Saved St", phone_number: "011 999 9999")

    job = Job.create!(
      customer_name: "",
      address: "",
      description: "Fix leak",
      status: :scheduled,
      priority: :maintenance,
      user: @super_admin,
      scheduled_date: Date.tomorrow,
      scheduled_time: Time.zone.parse("09:00"),
      client: client
    )

    assert_equal "Saved Client", job.customer_name
    assert_equal "456 Saved St", job.address
  end

  # --- Feature: Priority uses maintenance and project ---

  test "job priority enum has maintenance and project values" do
    job = create_job!(priority: :maintenance)
    assert job.maintenance?

    job2 = create_job!(priority: :project, customer_name: "Project Customer", scheduled_time: Time.zone.parse("10:00"))
    assert job2.project?
  end

  # --- Feature: Status dropdown in dashboard ---

  test "super_admin dashboard shows status dropdown in job table" do
    sign_in @super_admin
    create_job!(customer_name: "Dropdown Job", scheduled_time: Time.zone.parse("09:00"))

    get dashboard_path
    assert_response :success
    assert_includes response.body, "update_status"
    assert_includes response.body, "name=\"status\""
  end

  test "reporter dashboard shows status badge not dropdown" do
    sign_in @reporter
    create_job!(customer_name: "Report Job", scheduled_time: Time.zone.parse("10:00"))

    get dashboard_path
    assert_response :success
    assert_includes response.body, "badge badge-"
  end

  test "plumber without assigned jobs sees no status dropdown" do
    sign_in @plumber
    get dashboard_path
    assert_response :success
  end

  test "updating status via dropdown changes the job status" do
    sign_in @super_admin
    job = create_job!(status: :pending, scheduled_time: Time.zone.parse("11:00"))

    patch update_status_job_path(job), params: { status: "in_progress" }

    assert_response :redirect
    job.reload
    assert job.in_progress?
  end

  test "status dropdown shows current status value" do
    sign_in @super_admin
    job = create_job!(status: :in_progress, scheduled_time: Time.zone.parse("11:00"))

    get dashboard_path
    assert_response :success
    assert_includes response.body, "In progress"
    assert_includes response.body, "selected"
  end

  test "scheduler cannot change status via dropdown" do
    sign_in @scheduler
    job = create_job!(status: :pending, scheduled_time: Time.zone.parse("12:00"))

    patch update_status_job_path(job), params: { status: "in_progress" }

    assert_response :redirect
    job.reload
    assert_equal "pending", job.status
  end

  # --- Feature: Client CSV import ---

  test "admin can import clients from CSV" do
    sign_in @super_admin

    csv_content = "Name,Surname,Company,Contact Number,Address,Email Address\n"
    csv_content += "John,Smith,,011 123 4567,123 Main St,john@example.com\n"
    csv_content += ",,Acme Plumbing,011 987 6543,456 Business Ave,\n"
    csv_content += "Jane,Doe,Acme Corp,011 555 5555,789 Market St,jane@example.com\n"

    tempfile = Tempfile.new([ "import", ".csv" ])
    tempfile.write(csv_content)
    tempfile.rewind

    file = Rack::Test::UploadedFile.new(tempfile, "text/csv", "import.csv")

    post import_create_clients_path, params: { file: file }, as: :multipart

    tempfile.close
    tempfile.unlink

    assert_redirected_to clients_path
    assert(Client.exists?(name: "John Smith"))
    assert(Client.exists?(name: "Acme Plumbing"))
    assert(Client.exists?(name: "Acme Corp"))
  end
end
