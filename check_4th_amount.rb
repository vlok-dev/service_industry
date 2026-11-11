boq = Boq.find(1)
blob = boq.workbook_blob
File.open("C:/Users/User/AppData/Local/Temp/kilo/boq/live.xlsx", "wb") { |f| f.write(blob) }
puts "wrote live.xlsx (#{blob.bytesize} bytes)"

boq2 = Boq.new(
  project_title: "Test House",
  sheet_name: "TEST",
  claim_1_label: "1st claim",
  claim_1_amount: 1000,
  claim_2_label: "2nd claim",
  claim_2_amount: 2000,
  claim_3_label: "3rd claim",
  claim_3_amount: 3000,
  claim_4_label: "4th claim",
  claim_4_amount: 4000
)
boq2.items.build(row_type: "item", description: "Item", claimed_qty: 1, rate: 10000, position: 1)
blob2 = boq2.workbook_blob
File.open("C:/Users/User/AppData/Local/Temp/kilo/boq/with_4th_amount.xlsx", "wb") { |f| f.write(blob2) }
puts "wrote with_4th_amount.xlsx (#{blob2.bytesize} bytes)"

require "zip"
Zip::File.open_buffer(blob2) do |z|
  xml = z.find_entry("xl/worksheets/sheet1.xml").get_input_stream.read
  puts "H20 hard-coded 4000 present: #{xml.include?("<v>4000</v>")}"
  puts "H20 balance formula absent: #{!xml.include?("H12-H14-H16-H18")}"
end