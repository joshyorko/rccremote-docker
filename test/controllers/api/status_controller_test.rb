require "test_helper"

class Api::StatusControllerTest < ActionDispatch::IntegrationTest
  test "returns status payload" do
    get api_status_url

    assert_response :success
    parsed = JSON.parse(response.body)
    assert parsed.key?("statistics")
  end
end
