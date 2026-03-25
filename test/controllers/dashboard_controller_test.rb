require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:one)) }

  test "renders dashboard" do
    get root_url

    assert_response :success
    assert_includes response.body, "System status"
  end
end
