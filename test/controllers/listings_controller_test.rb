require "test_helper"

class ListingsControllerTest < ActionDispatch::IntegrationTest
  test "index responds successfully and lists fixture listings" do
    get listings_path
    assert_response :success
    assert_select "td", text: listings(:good_parcel).title
  end

  test "root route also loads the dashboard" do
    get root_path
    assert_response :success
  end

  test "source filter narrows the results" do
    get listings_path, params: { source: "craigslist" }
    assert_response :success
    assert_select "td", text: listings(:good_parcel).title
    assert_select "td", { text: listings(:low_score_parcel).title, count: 0 }
  end

  test "max_price filter excludes listings above the ceiling" do
    get listings_path, params: { max_price: 5_000 }
    assert_response :success
    assert_select "td", text: listings(:good_parcel).title
    assert_select "td", { text: listings(:low_score_parcel).title, count: 0 }
  end
end
