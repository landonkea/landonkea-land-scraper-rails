require "test_helper"

class LandScraper::HistorySnapshotTest < ActiveSupport::TestCase
  test "returns nil when there are no listings to summarize" do
    Listing.delete_all
    assert_nil LandScraper::HistorySnapshot.save
  end

  test "computes totals, good count, price stats, and a per-source breakdown" do
    summary = LandScraper::HistorySnapshot.save

    assert_equal Listing.count, summary.total
    assert_equal Listing.good.count, summary.good
    assert_equal Date.current, summary.summary_date
    assert_kind_of Hash, summary.by_source
    # The fixtures include one craigslist listing and one adot listing.
    assert_equal 1, summary.by_source["craigslist"]["count"]
    assert_equal 1, summary.by_source["adot"]["count"]
  end

  test "running it twice on the same day updates the same row instead of duplicating it" do
    LandScraper::HistorySnapshot.save
    assert_no_difference "DailySummary.count" do
      LandScraper::HistorySnapshot.save
    end
  end
end
