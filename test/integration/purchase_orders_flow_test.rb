require "test_helper"

class PurchaseOrdersFlowTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @user = User.find_or_create_by!(email: "owner@admin.com") do |u|
      u.name = "Owner Admin"
      u.password = "password123"
      u.role = :super_admin
    end
  end

  def create_job
    Job.create!(
      customer_name: "C", address: "A", description: "D",
      status: :scheduled, priority: :medium, user: @user,
      scheduled_date: Date.today, scheduled_time: Time.zone.parse("09:00")
    )
  end

  test "po total (incl. VAT) is computed and shown from saved line items" do
    sign_in @user
    job = create_job

    post job_purchase_orders_path(job), params: {
      purchase_order: {
        supplier_name: "Acme", order_date: Date.today,
        items_attributes: { "0" => { description: "Pipe", quantity: 2, unit_price: 10.00 } }
      }
    }
    assert_response :redirect
    follow_redirect!
    assert_response :success

    body = response.body
    assert_includes body, "23.00", "expected total incl. VAT (23.00) on PO show"
    assert job.purchase_orders.reload.any?, "PO was not created"
  end

  test "po total persists total_amount (after VAT) on the record" do
    sign_in @user
    job = create_job
    po = job.purchase_orders.create!(
      supplier_name: "Acme", order_date: Date.today, created_by: @user,
      items_attributes: [ { description: "Pipe", quantity: 2, unit_price: 10.00 } ]
    )
    po.reload
    assert_in_delta 23.00, po.total_amount.to_f, 0.01, "total_amount should be the after-VAT total"
  end
end
