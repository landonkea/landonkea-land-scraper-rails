require "test_helper"

class ListingTest < ActiveSupport::TestCase
  # good? should reflect the same >= 50 threshold the dashboard and Python's get_stats() both use.
  test "good? is true at or above the good score threshold" do
    assert listings(:good_parcel).good?
    assert_not listings(:low_score_parcel).good?
  end

  # The unique index on [source, source_id] is what stops the same parcel being saved twice.
  test "source_id must be unique within the same source" do
    duplicate = Listing.new(
      source: listings(:good_parcel).source,
      source_id: listings(:good_parcel).source_id,
      title: "Duplicate listing", price: 1, url: "https://example.com", score: 0
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:source_id], "has already been taken"
  end

  # The same source_id is fine as long as it's under a different source — sources have
  # their own independent id namespaces (a Craigslist URL vs. a county parcel number).
  test "the same source_id is allowed under a different source" do
    same_id_different_source = Listing.new(
      source: "landmodo",
      source_id: listings(:good_parcel).source_id,
      title: "Different source, same id string", price: 1, url: "https://example.com", score: 0
    )
    assert same_id_different_source.valid?
  end

  # good scope should only pull back listings scoring 50+.
  test "good scope only returns high-scoring listings" do
    assert_includes Listing.good, listings(:good_parcel)
    assert_not_includes Listing.good, listings(:low_score_parcel)
  end

  # best_first should rank the higher score ahead of the lower one.
  test "best_first orders by score descending" do
    assert_equal listings(:good_parcel), Listing.best_first.first
  end
end
