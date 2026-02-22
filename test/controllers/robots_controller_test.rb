require "test_helper"
require "fileutils"

class RobotsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @robots_path = Rails.root.join("tmp/test/robots")
    @zips_path = Rails.root.join("tmp/test/hololib_zip")

    FileUtils.rm_rf(@robots_path)
    FileUtils.rm_rf(@zips_path)

    ENV["ROBOTS_PATH"] = @robots_path.to_s
    ENV["HOLOLIB_ZIP_PATH"] = @zips_path.to_s
  end

  teardown do
    ENV.delete("ROBOTS_PATH")
    ENV.delete("HOLOLIB_ZIP_PATH")

    FileUtils.rm_rf(@robots_path)
    FileUtils.rm_rf(@zips_path)
  end

  test "renders robots index" do
    get robots_url

    assert_response :success
    assert_includes response.body, "ROBOT MANAGEMENT"
  end

  test "creates robot and redirects" do
    post robots_url, params: { name: "demo" }

    assert_redirected_to robot_url("demo")
    assert File.directory?(@robots_path.join("demo"))
  end

  test "missing robot redirects to index" do
    get robot_url("missing")

    assert_redirected_to robots_url
  end
end
