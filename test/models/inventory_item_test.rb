require "test_helper"

class InventoryItemTest < ActiveSupport::TestCase
  def setup
    @item = InventoryItem.create!(
      code: "COP-15",
      name: "Copper Pipe 15mm",
      unit_price: 12.50,
      unit: "m"
    )
  end

  test "search_by_code finds by code regardless of case" do
    assert_inventory_searched("cop")
    assert_inventory_searched("COP")
    assert_inventory_searched("COP-15")
    assert_inventory_searched("15")
  end

  test "search_by_code returns nothing for bogus queries" do
    assert_empty InventoryItem.search_by_code("xyz")
    assert_empty InventoryItem.search_by_code("")
  end

  private

  def assert_inventory_searched(query)
    assert_includes InventoryItem.search_by_code(query),
                    @item,
                    "expected to find #{@item.code} for query '#{query}'"
  end
end
