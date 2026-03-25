if Rails.env.development?
  default_user_email = "joshua.yorko@gmail.com"
  default_user_password = "password123!"

  user = User.find_or_create_by!(email_address: default_user_email) do |record|
    record.password = default_user_password
    record.password_confirmation = default_user_password
  end

  puts "Development user ready: #{user.email_address}"
end
