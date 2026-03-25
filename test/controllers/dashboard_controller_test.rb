require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:one)) }

  test "renders dashboard" do
    get root_url

    assert_response :success
    assert_includes response.body, "Runtime overview"
    assert_includes response.body, "Jump anywhere"
    assert_includes response.body, "Workspaces"
    assert_includes response.body, "Bundles"
  end
end
