require "test_helper"

class SmokeNewFeaturesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @user = User.find_or_create_by!(email: "smoke@admin.com") do |u|
      u.name = "Smoke Admin"
      u.password = "password123"
      u.role = :super_admin
    end
  end

  def valid_job(project: false)
    Job.create!(
      customer_name: "Smoke Customer",
      address: "123 Smoke St",
      description: "Test work",
      status: :scheduled,
      priority: :maintenance,
      user: @user,
      scheduled_date: Date.new(2026, 9, 10),
      scheduled_time: Time.zone.parse("09:00"),
      is_project: project
    )
  end

  test "master data pages render" do
    sign_in @user
    get suppliers_path
    assert_response :success

    supplier = Supplier.create!(name: "Test Supplier", contact_person: "Sam", email: "sam@example.com", phone: "011 000 0000", address: "1 St")
    get supplier_path(supplier)
    assert_response :success

    get new_supplier_path
    assert_response :success

    get inventory_items_path
    assert_response :success

    item = InventoryItem.create!(code: "TEST-001", name: "Test Pipe", unit_price: 9.99, unit: "m")
    get inventory_item_path(item)
    assert_response :success

    get new_inventory_item_path
    assert_response :success
  end

  test "job multi-day + project + claims pages render" do
    sign_in @user
    project = valid_job(project: true)
    get job_path(project)
    assert_response :success, "job show failed: #{response.body[0, 500]}"

    get edit_job_path(project)
    assert_response :success

    get job_claims_path(project)
    assert_response :success, "claims index failed: #{response.body[0, 500]}"

    get new_job_claim_path(project)
    assert_response :success, "new claim failed: #{response.body[0, 500]}"
  end

  test "claim lifecycle renders" do
    sign_in @user
    project = valid_job(project: true)
    claim = project.claims.create!(amount: 100.00, claim_date: Date.today, status: :pending, reference: "INV-1")
    get job_claim_path(project, claim)
    assert_response :success, "claim show failed: #{response.body[0, 500]}"

    get edit_job_claim_path(project, claim)
    assert_response :success
  end

  test "purchase order form renders with supplier dropdown and inventory code lookup" do
    sign_in @user
    job = valid_job
    get new_job_purchase_order_path(job)
    assert_response :success, "PO new failed: #{response.body[0, 500]}"

    get edit_job_purchase_order_path(job, job.purchase_orders.create!(supplier_name: "Test Supplier", order_date: Date.today, created_by: @user))
    assert_response :success, "PO edit failed: #{response.body[0, 500]}"
  end

  test "inventory code search is case-insensitive and returns json" do
    InventoryItem.create!(code: "COP-15", name: "Copper Pipe 15mm", unit_price: 12.50, unit: "m")
    sign_in @user

    get search_inventory_items_path(q: "COP", format: :json)
    assert_response :success
    json = ActiveSupport::JSON.decode(@response.body)
    assert_equal "COP-15", json.first["code"]
    assert_equal "Copper Pipe 15mm", json.first["name"]

    get search_inventory_items_path(q: "cop", format: :json)
    json = ActiveSupport::JSON.decode(@response.body)
    assert_equal "COP-15", json.first["code"]
  end

  test "add extra day action works" do
    sign_in @user
    job = valid_job
    patch add_extra_day_job_path(job)
    assert_response :redirect
    job.reload
    assert_equal (Date.new(2026, 9, 10) + 1.day), job.scheduled_end_date
  end

  test "super admin defaults to dark theme" do
    sign_in @user
    assert_equal "dark", @user.effective_theme
    get dashboard_path
    assert_response :success
    assert_includes response.body, 'data-theme="dark"'
  end

  test "theme preference persists across sessions" do
    sign_in @user
    assert_equal "dark", @user.effective_theme

    patch theme_path, params: { theme: "light" }, as: :json
    assert_response :success

    @user.reload
    assert_equal "light", @user.theme_preference
    assert_equal "light", @user.effective_theme

    get dashboard_path
    assert_response :success
    assert_includes response.body, 'data-theme="light"'
  end

  test "theme toggle rejects invalid values" do
    sign_in @user
    patch theme_path, params: { theme: "purple" }, as: :json
    assert_response :success
    @user.reload
    assert_nil @user.theme_preference
  end

  test "purchase order print page renders" do
    sign_in @user
    job = valid_job
    po = job.purchase_orders.create!(
      supplier_name: "Test Supplier",
      order_date: Date.today,
      created_by: @user
    )
    po.items.create!(description: "Test Item", quantity: 2, unit_price: 10.00)

    get print_job_purchase_order_path(job, po)
    assert_response :success
    assert_includes response.body, po.po_number
    assert_includes response.body, "Purchase Order"
  end

  test "non-super-admin user defaults to light theme" do
    plumber = User.find_or_create_by!(email: "plumber@test.com") do |u|
      u.name = "Test Plumber"
      u.password = "password123"
      u.role = :plumber
    end
    sign_in plumber
    assert_equal "light", plumber.effective_theme
  end
end
