require "test_helper"
require "zip"

class BoqWorkbookBuilderTest < ActiveSupport::TestCase
  def rows
    [
      { kind: :heading, description: "GROUND FLOOR" },
      { kind: :heading, description: "ENSUITE 1" },
      { kind: :spacer },
      { kind: :item, description: "Installation of wash hand basins", bill_qty: 2, claimed_qty: 2, rate: 5000 },
      { kind: :spacer },
      { kind: :item, description: "Installation of shower", bill_qty: 1, claimed_qty: 1, rate: 5000 }
    ]
  end

  def claims
    [
      { label: "1st claim", amount: 62430.5 },
      { label: "2nd claim", amount: 47570 },
      { label: "3rd claim - February", amount: 187612.9 },
      { label: "4th claim - April", amount: nil }
    ]
  end

  def builder(custom_rows = rows, custom_claims = claims)
    BoqWorkbookBuilder.new(sheet_name: "Avonmouth", title: "House Avonmouth", rows: custom_rows, claims: custom_claims)
  end

  def zip_entries
    file = Tempfile.new([ "boq-test", ".xlsx" ])
    file.binmode
    file.write(builder.to_blob)
    file.close

    entries = {}
    Zip::File.open(file.path) do |zip|
      zip.each do |entry|
        stream = entry.get_input_stream
        entries[entry.name] = stream.read
        stream.close
      end
    end
    file.unlink
    entries
  end

  def sheet_xml
    zip_entries["xl/worksheets/sheet1.xml"]
  end

  test "sheet name is uppercased and sanitised" do
    assert_equal "AVONMOUTH", builder.sheet_name
  end

  test "sheet name is truncated to 31 characters" do
    long = BoqWorkbookBuilder.new(sheet_name: "A" * 40, title: "x", rows: rows, claims: claims)
    assert_equal 31, long.sheet_name.length
  end

  test "title is uppercased" do
    assert_equal "HOUSE AVONMOUTH", builder.title
  end

  test "layout follows the content rows" do
    assert_equal 18, builder.total_row
    assert_equal 14, builder.first_item_row
    assert_equal 16, builder.last_item_row
    assert_equal 26, builder.last_row
  end

  test "total value is the sum of claimed times rate" do
    assert_equal 15000.0, builder.total_value
  end

  test "workbook contains the header labels" do
    strings = zip_entries["xl/sharedStrings.xml"]
    assert_includes strings, "Page"
    assert_includes strings, "Bill Qty"
    assert_includes strings, "HOUSE AVONMOUTH"
  end

  test "workbook contains the line formulas and the total" do
    xml = sheet_xml
    assert_includes xml, "F14*G14"
    assert_includes xml, "F16*G16"
    assert_includes xml, "SUM(H14:H16)"
  end

  test "last claim is the balance of the total" do
    assert_includes sheet_xml, "H18-H20-H22-H24"
  end

  test "workbook uses the reference column widths" do
    xml = sheet_xml
    assert_includes xml, 'width="10" customWidth="1"'
    assert_includes xml, 'width="7.44" customWidth="1"'
    assert_includes xml, 'width="33" customWidth="1"'
    assert_includes xml, 'width="16.11" customWidth="1"'
    assert_includes xml, 'defaultColWidth="9.109375"'
  end

  test "workbook uses the reference page setup" do
    xml = sheet_xml
    assert_includes xml, 'defaultRowHeight="14.4"'
    assert_includes xml, 'ySplit="8"'
    assert_includes xml, 'topLeftCell="A9"'
    assert_includes xml, 'orientation="portrait"'
    assert_includes xml, 'fitToHeight="0"'
    assert_includes xml, 'paperSize="9"'
    assert_includes xml, 'left="0.7"'
    assert_includes xml, 'top="0.75"'
    assert_includes xml, 'rgb="FFFFFF00"'
  end

  test "print area covers the last claim row" do
    assert_includes zip_entries["xl/workbook.xml"], "$A$1:$H$26"
  end

  test "rows without a total formula stay empty" do
    custom = BoqWorkbookBuilder.new(
      sheet_name: "TEST",
      title: "TEST",
      rows: [ { kind: :item, description: "Item", claimed_qty: 1, rate: 10, total_formula: false } ],
      claims: [ { label: "1st claim", amount: 5 } ]
    )
    file = Tempfile.new([ "boq-test", ".xlsx" ])
    file.binmode
    file.write(custom.to_blob)
    file.close
    xml = nil
    Zip::File.open(file.path) do |zip|
      entry = zip.find_entry("xl/worksheets/sheet1.xml")
      stream = entry.get_input_stream
      xml = stream.read
      stream.close
    end
    file.unlink
    refute_includes xml, "F11*G11"
  end

  test "wrapped descriptions increase the row height" do
    custom = BoqWorkbookBuilder.new(
      sheet_name: "TEST",
      title: "TEST",
      rows: [
        { kind: :item, description: "Installation of wash hand basin in garage" },
        { kind: :item, description: "Supply and install 200lt geyser including tray and timber bed in rafters, all hot water pipes lagged" }
      ],
      claims: [ { label: "1st claim", amount: 5 } ]
    )
    file = Tempfile.new([ "boq-test", ".xlsx" ])
    file.binmode
    file.write(custom.to_blob)
    file.close
    xml = nil
    Zip::File.open(file.path) do |zip|
      entry = zip.find_entry("xl/worksheets/sheet1.xml")
      stream = entry.get_input_stream
      xml = stream.read
      stream.close
    end
    file.unlink
    assert_includes xml, 'ht="26.4"'
    assert_includes xml, 'ht="39.6"'
  end
end
