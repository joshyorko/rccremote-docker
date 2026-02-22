require "test_helper"

class CatalogsControllerTest < ActionDispatch::IntegrationTest
  test "renders catalogs index" do
    get catalogs_url

    assert_response :success
    assert_includes response.body, "HOLOTREE CATALOGS"
  end

  test "rebuild redirects" do
    post rebuild_catalogs_url

    assert_redirected_to catalogs_url
  end
end
