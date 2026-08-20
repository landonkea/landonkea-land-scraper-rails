require "test_helper"

class LandScraper::ListingBuilderTest < ActiveSupport::TestCase
  test "returns nil for a listing should_skip? rejects" do
    result = LandScraper::ListingBuilder.build(
      source: "craigslist", source_id: "1", title: "Room for rent", price: 500, url: "https://example.com"
    )
    assert_nil result
  end

  test "returns a scored attribute hash for a listing that passes the filter" do
    result = LandScraper::ListingBuilder.build(
      source: "craigslist", source_id: "1", title: "5 acres with water well", price: 4_000,
      url: "https://example.com", location: "Prescott, AZ", description: "no hoa"
    )
    assert_equal "craigslist", result[:source]
    # baseline 40 + well 35 + no-hoa 10 + under-$5k 15 + "acres"/GOOD match 10 = 110, clamped to 100
    assert_equal 100, result[:score]
  end
end
