require "test_helper"

class DailySummaryTest < ActiveSupport::TestCase
  # by_source is stored as a text column but should come back out as a real Hash, not a raw JSON string.
  test "by_source deserializes into a Hash" do
    summary = daily_summaries(:today)
    assert_kind_of Hash, summary.by_source
    assert_equal 33, summary.by_source["craigslist"]["count"]
  end

  # summary_date has to be unique — only one snapshot per calendar day.
  test "summary_date must be unique" do
    duplicate = DailySummary.new(summary_date: daily_summaries(:today).summary_date, total: 1, good: 1)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:summary_date], "has already been taken"
  end

  # default_scope orders oldest to newest, so a fresh query should list yesterday before today.
  test "defaults to chronological order" do
    dates = DailySummary.all.map(&:summary_date)
    assert_equal dates.sort, dates
  end
end
