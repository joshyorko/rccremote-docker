require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "renders dashboard" do
    get root_url

    assert_response :success
    assert_includes response.body, "System status"
  end
end
