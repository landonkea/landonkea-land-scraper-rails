require "test_helper"

class LandScraper::DiscordNotifierTest < ActiveSupport::TestCase
  test "returns false and never hits the network when no webhook is configured" do
    notifier = LandScraper::DiscordNotifier.new(webhook_url: nil)
    result = notifier.send_alert(title: "Test listing", price: 5_000, url: "https://example.com", location: "AZ", score: 80, source: "craigslist")
    assert_equal false, result
  end

  test "returns false without posting when the price is over the alert ceiling" do
    notifier = LandScraper::DiscordNotifier.new(webhook_url: "https://discord.com/api/webhooks/fake")
    result = notifier.send_alert(title: "Expensive parcel", price: 150_000, url: "https://example.com", location: "AZ", score: 90, source: "craigslist")
    assert_equal false, result
  end
end
