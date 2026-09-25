require "test_helper"

class DigitalJobCardsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get digital_job_cards_index_url
    assert_response :success
  end

  test "should get create" do
    get digital_job_cards_create_url
    assert_response :success
  end
end
