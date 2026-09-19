require "test_helper"

class ForecastsControllerTest < ActionDispatch::IntegrationTest
  test "root renders the address form" do
    get root_path
    assert_response :success
    assert_select "form[action=?][method=get]", forecast_path
    assert_select "input[name=address][required]"
  end

  test "accepts a valid address" do
    get forecast_path, params: { address: "1 Infinite Loop, Cupertino, CA" }
    assert_response :success
    assert_select "h1", /1 Infinite Loop, Cupertino, CA/
  end

  test "rejects a blank address" do
    get forecast_path, params: { address: "  " }
    assert_response :unprocessable_content
    assert_select "#address-errors li", /can't be blank/
  end

  test "rejects a missing address param" do
    get forecast_path
    assert_response :unprocessable_content
  end

  test "escapes user input" do
    get forecast_path, params: { address: "<script>alert(1)</script>" }
    assert_response :success
    assert_no_match "<script>alert(1)</script>", response.body
  end
end