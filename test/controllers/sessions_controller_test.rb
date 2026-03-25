require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_session_path
    assert_response :success
    assert_no_app_navigation
  end

  test "create with valid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create with invalid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "destroy" do
    sign_in_as(User.take)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end

  private
    def assert_no_app_navigation
      assert_select "nav[aria-label='Primary']", count: 0
      assert_select "a", text: "Dashboard", count: 0
      assert_select "a", text: "Robots", count: 0
      assert_select "a", text: "Catalogs", count: 0
      assert_select "a", text: "Hololib ZIPs", count: 0
      assert_select "a", text: "Log out", count: 0
    end
end
