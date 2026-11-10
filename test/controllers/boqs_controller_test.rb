require "test_helper"

class BoqsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @user = User.find_or_create_by!(email: "boq@test.com") do |user|
      user.name = "BoQ Admin"
      user.password = "password123"
      user.role = :super_admin
    end
    @boq = Boq.create!(project_title: "House Avonmouth", sheet_name: "AVONMOUTH")
    @boq.items.create!(row_type: "heading", description: "GROUND FLOOR", position: 1)
    @boq.items.create!(row_type: "spacer", position: 2)
    @boq.items.create!(row_type: "item", description: "Installation of shower", claimed_qty: 1, rate: 5000, position: 3)
  end

  test "index lists the bills of quantities" do
    sign_in @user
    get boqs_path
    assert_response :success
    assert_match "House Avonmouth", response.body
    assert_match "AVONMOUTH", response.body
  end

  test "index requires sign in" do
    get boqs_path
    assert_redirected_to new_user_session_path
  end

  test "sidebar shows the BoQ tab for office users" do
    sign_in @user
    get boqs_path
    assert_response :success
    assert_match(/BoQ&#39;s|BoQ's/, response.body)
    assert_match "href=\"/boqs\"", response.body
  end

  test "new renders the form" do
    sign_in @user
    get new_boq_path
    assert_response :success
    assert_match "Project title", response.body
    assert_match "Bill Qty", response.body
  end

  test "create stores the project, claims and line items" do
    sign_in @user
    assert_difference "Boq.count", 1 do
      assert_difference "BoqItem.count", 3 do
        post boqs_path, params: {
          boq: {
            project_title: "Flat 2 Rosebank",
            sheet_name: "ROSEBANK",
            claim_1_label: "1st claim",
            claim_1_amount: "1000",
            claim_2_label: "2nd claim",
            claim_2_amount: "2000",
            claim_3_label: "3rd claim",
            claim_3_amount: "3000",
            claim_4_label: "4th claim",
            items_attributes: {
              "0" => { row_type: "heading", description: "KITCHEN" },
              "1" => { row_type: "spacer" },
              "2" => { row_type: "item", description: "Installation of sink", claimed_qty: "1", rate: "750" }
            }
          }
        }
      end
    end

    boq = Boq.order(:id).last
    assert_equal "Flat 2 Rosebank", boq.project_title
    assert_equal "ROSEBANK", boq.sheet_name
    assert_equal 3, boq.items.count
    assert_equal 750.0, boq.total_value
  end

  test "create rejects a blank project title" do
    sign_in @user
    assert_no_difference "Boq.count" do
      post boqs_path, params: { boq: { project_title: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "edit renders the form" do
    sign_in @user
    get edit_boq_path(@boq)
    assert_response :success
    assert_match "GROUND FLOOR", response.body
  end

  test "update changes the project" do
    sign_in @user
    patch boq_path(@boq), params: { boq: { project_title: "House Avonmouth 2" } }
    assert_redirected_to boqs_path
    assert_equal "House Avonmouth 2", @boq.reload.project_title
  end

  test "destroy removes the bill of quantities" do
    sign_in @user
    assert_difference "Boq.count", -1 do
      delete boq_path(@boq)
    end
    assert_redirected_to boqs_path
  end

  test "download returns an excel workbook" do
    sign_in @user
    get download_boq_path(@boq)
    assert_response :success
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", response.media_type
    assert_match "BOQ_-_House_Avonmouth_-_4th_claim.xlsx", response.headers["Content-Disposition"]
    assert_equal "PK", response.body[0, 2]
  end
end
