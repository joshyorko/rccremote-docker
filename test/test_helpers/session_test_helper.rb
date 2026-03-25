module SessionTestHelper
  def sign_in_as(user)
    post session_path, params: {
      email_address: user.email_address,
      password: "password"
    }
  end

  def sign_out
    delete session_path
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include SessionTestHelper
end
