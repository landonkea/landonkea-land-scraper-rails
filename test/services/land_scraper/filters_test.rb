require "test_helper"

# These assertions pin down the exact point values ported from the Python filters.py —
# the whole point of this port is that a listing scores the same in Rails as it did in
# the original scraper, so these numbers are checked against the Python source, not
# just against whatever this Ruby code happens to compute.
class LandScraper::FiltersTest < ActiveSupport::TestCase
  test "every listing starts at the 40-point baseline" do
    assert_equal 40, LandScraper::Filters.score_listing("Plain land parcel", "", 0)
  end

  test "a well, owner financing, and a tax deed each add their own bonus" do
    text = "owner financing, tax deed sale, no hoa, paved road, electric available, " \
           "mobile home allowed, rv ok, adjacent to public land, low tax, cell service, acreage"
    # Every bonus in the scoring table stacks up but is capped at 100.
    assert_equal 100, LandScraper::Filters.score_listing("Land with water well", text, 4000)
  end

  test "price bonuses step down as the price climbs" do
    assert_equal 55, LandScraper::Filters.score_listing("plain", "", 4_000)   # under $5k: +15
    assert_equal 50, LandScraper::Filters.score_listing("plain", "", 10_000)  # under $15k: +10
    assert_equal 45, LandScraper::Filters.score_listing("plain", "", 25_000)  # under $30k: +5
    assert_equal 40, LandScraper::Filters.score_listing("plain", "", 50_000)  # $30k+: no bonus
  end

  test "price-per-acre earns its own bonus on top of the flat price bonus" do
    # 2 acres for $1,500 = $750/acre (under $1k/acre: +20), price under $5k: +15,
    # and "acres" itself matches the GOOD pattern: +10. 40 + 20 + 15 + 10 = 85.
    assert_equal 85, LandScraper::Filters.score_listing("plain", "2 acres", 1_500)
  end

  test "should_skip? rejects rentals outright" do
    assert LandScraper::Filters.should_skip?("Land for rent")
  end

  test "should_skip? rejects HOA listings unless they explicitly say no HOA" do
    assert LandScraper::Filters.should_skip?("Land with HOA fees")
    assert_not LandScraper::Filters.should_skip?("Land with no HOA")
  end

  test "should_skip? rejects parcels under a fifth of an acre" do
    assert LandScraper::Filters.should_skip?("Tiny lot", "0.1 acres")
    assert_not LandScraper::Filters.should_skip?("5 acres of vacant land")
  end

  test "parse_acres reads acreage first, then falls back to square footage" do
    assert_in_delta 5.5, LandScraper::Filters.parse_acres("5.5 acres available"), 0.001
    # 43,560 sq ft is exactly one acre.
    assert_in_delta 1.0, LandScraper::Filters.parse_acres("43,560 sq ft lot"), 0.001
    assert_nil LandScraper::Filters.parse_acres("no size mentioned here")
  end
end
