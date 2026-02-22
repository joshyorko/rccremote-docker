require "test_helper"

class CatalogsControllerTest < ActionDispatch::IntegrationTest
  test "renders catalogs index" do
    get catalogs_url

    assert_response :success
    assert_includes response.body, "Holotree catalogs"
  end

  test "rebuild redirects" do
    post rebuild_catalogs_url

    assert_redirected_to catalogs_url
  end

  test "rebuild returns json payload for stimulus flow" do
    post rebuild_catalogs_url(format: :json)

    assert_includes [ 200, 422 ], response.status

    payload = JSON.parse(response.body)
    assert payload.key?("success")
    assert payload.key?("message")
  end
end
