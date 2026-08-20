require "test_helper"

class LandScraper::CraigslistScraperTest < ActiveSupport::TestCase
  # Real HTML fragment shaped like Craigslist's search-result markup, small enough to
  # keep the test fast and readable, but with the same class names the scraper looks for.
  SAMPLE_HTML = <<~HTML
    <ul>
      <li class="cl-static-search-result">
        <a href="/rea/d/phoenix-5-acres-with-water-well/1.html">
          <div class="title">5 acres with water well, no HOA</div>
          <div class="price">$4,500</div>
          <div class="location">Phoenix, AZ</div>
        </a>
      </li>
      <li class="cl-static-search-result">
        <a href="/rea/d/phoenix-room-for-rent/2.html">
          <div class="title">Room for rent near downtown</div>
          <div class="price">$800</div>
          <div class="location">Phoenix, AZ</div>
        </a>
      </li>
    </ul>
  HTML

  test "parses listing rows and filters out ones should_skip? rejects" do
    results = with_stubbed_get(->(url, **) { url.include?("phoenix") ? SAMPLE_HTML : nil }) do
      LandScraper::CraigslistScraper.new.call
    end

    # Only the well listing should survive — the "room for rent" one gets filtered by should_skip?.
    assert_equal 1, results.count { |r| r[:source_id].include?("water-well") }
    assert_equal 0, results.count { |r| r[:source_id].include?("room-for-rent") }

    listing = results.find { |r| r[:source_id].include?("water-well") }
    assert_equal 4_500.0, listing[:price]
    assert_equal "Phoenix, AZ", listing[:location]
    assert_equal "https://phoenix.craigslist.org/rea/d/phoenix-5-acres-with-water-well/1.html", listing[:url]
  end

  test "a failed request for one region just yields no listings, not an error" do
    results = with_stubbed_get(->(*) { nil }) { LandScraper::CraigslistScraper.new.call }
    assert_equal [], results
  end

  private

  # Temporarily replaces HttpClient.get with fake_get for the duration of the block,
  # then restores the original method no matter what happens inside the block.
  def with_stubbed_get(fake_get)
    original = LandScraper::HttpClient.method(:get)
    LandScraper::HttpClient.define_singleton_method(:get) { |*args, **kwargs| fake_get.call(*args, **kwargs) }
    yield
  ensure
    LandScraper::HttpClient.define_singleton_method(:get, original)
  end
end
