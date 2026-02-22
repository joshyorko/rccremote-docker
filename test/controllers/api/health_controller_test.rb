require "test_helper"

class Api::HealthControllerTest < ActionDispatch::IntegrationTest
  test "returns health payload" do
    get api_health_url

    assert_response :success
    parsed = JSON.parse(response.body)
    assert_equal "healthy", parsed.fetch("status")
  end
end
