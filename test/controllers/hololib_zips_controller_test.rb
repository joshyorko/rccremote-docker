require "test_helper"
require "fileutils"

class HololibZipsControllerTest < ActionDispatch::IntegrationTest
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

  test "renders zip index" do
    get hololib_zips_url

    assert_response :success
    assert_includes response.body, "Hololib ZIP files"
  end

  test "upload with no file redirects" do
    post hololib_zips_url

    assert_redirected_to hololib_zips_url
  end

  test "destroy missing file redirects" do
    delete hololib_zip_url(filename: "missing.zip")

    assert_redirected_to hololib_zips_url
  end
end
