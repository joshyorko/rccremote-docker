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
    assert_includes response.body, "Robot management"
  end

  test "creates robot and redirects" do
    post robots_url, params: { name: "demo" }

    assert_redirected_to robot_url("demo")
    assert File.directory?(@robots_path.join("demo"))
  end

  test "renders core file editor" do
    post robots_url, params: { name: "demo" }

    get edit_files_robot_url("demo")

    assert_response :success
    assert_includes response.body, "Edit core files"
  end

  test "updates robot core files" do
    post robots_url, params: { name: "demo" }

    patch update_files_robot_url("demo"), params: {
      robot_yaml: "tasks:\n  Test:\n    shell: echo hi\n",
      conda_yaml: "channels:\n  - conda-forge\n\ndependencies:\n  - python=3.12\n"
    }

    assert_redirected_to robot_url("demo")
    assert_includes @robots_path.join("demo", "robot.yaml").read, "shell: echo hi"
    assert_includes @robots_path.join("demo", "conda.yaml").read, "python=3.12"
  end

  test "missing robot redirects to index" do
    get robot_url("missing")

    assert_redirected_to robots_url
  end
end
