require "test_helper"

class PurchaseOrderItemTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(name: "Owner Admin", email: "owner@admin.com", password: "password123", role: :super_admin)
    @job = Job.create!(
      customer_name: "C", address: "A", description: "D",
      status: :scheduled, priority: :maintenance, user: @user,
      scheduled_date: Date.today, scheduled_time: Time.zone.parse("09:00")
    )
    @po = @job.purchase_orders.create!(
      supplier_name: "Acme", order_date: Date.today, created_by: @user
    )
  end

  test "accepts decimal quantity values such as 0.01, 0.5, 0.7, 0.45" do
    [0.01, 0.5, 0.7, 0.45].each do |qty|
      item = @po.items.create!(description: "Item", quantity: qty, unit_price: 10.00)
      assert_equal qty, item.quantity.to_f
    end
  end

  test "rejects zero or negative quantity" do
    item = @po.items.build(description: "Item", quantity: 0, unit_price: 10.00)
    assert_not item.valid?
    assert_includes item.errors[:quantity], "must be greater than 0"
  end

  test "total is quantity multiplied by unit price" do
    item = @po.items.create!(description: "Item", quantity: 0.5, unit_price: 10.00)
    assert_in_delta 5.00, item.total.to_f, 0.001
  end
end
