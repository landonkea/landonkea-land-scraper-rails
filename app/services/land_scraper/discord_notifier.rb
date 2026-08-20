# Posts one land listing to a Discord channel as a rich embed message. This is a port of
# discord.py's send_alert() — same fields, same color thresholds, same rate-limit handling.
module LandScraper
  class DiscordNotifier
    # Listings above this price never get posted to Discord, even if they score well —
    # keeps the channel focused on genuinely cheap parcels. Matches Python's MAX_PRICE.
    MAX_PRICE = 100_000

    # Discord asks bots to wait between messages; 1.5s matches the pause the Python
    # version used after every single post, successful or not.
    RATE_LIMIT_PAUSE = 1.5

    # webhook_url is passed in rather than read from ENV directly, so tests can swap in
    # a fake URL (or nil) without touching real environment variables.
    def initialize(webhook_url: ENV["DISCORD_WEBHOOK_URL"])
      @webhook_url = webhook_url
    end

    # Sends one listing as a Discord embed. Returns true/false purely so callers/tests can
    # tell whether a real post happened, though nothing here raises on network failure —
    # a bad listing alert shouldn't take down the whole scrape job.
    def send_alert(title:, price:, url:, location:, score:, source:)
      # No webhook configured (e.g. running locally without the secret) — just log it instead of crashing.
      if @webhook_url.blank?
        Rails.logger.info("[LandScraper] (no webhook) [#{score}] $#{format('%.0f', price)} - #{title.to_s[0, 50]}")
        return false
      end

      # Listings over the price ceiling still get saved to the database, just not alerted on.
      return false if price.to_f > MAX_PRICE

      post_embed(build_embed(title:, price:, url:, location:, score:, source:))
    ensure
      # Always pause after attempting a send, win or lose, same as the Python version's
      # unconditional time.sleep(1.5) at the bottom of send_alert().
      sleep(RATE_LIMIT_PAUSE) unless Rails.env.test?
    end

    private

    # Builds the JSON structure Discord expects for a rich embed card.
    def build_embed(title:, price:, url:, location:, score:, source:)
      {
        # 0x00ff00 green for great matches, yellow for decent, orange for the rest — exact
        # same score cutoffs (70 / 50) the Python version used.
        title: "[#{score}/100] $#{format('%.0f', price)} - #{title.to_s[0, 75]}",
        url: url,
        color: score >= 70 ? 0x00ff00 : score >= 50 ? 0xffff00 : 0xff9900,
        fields: [
          { name: "Location", value: location.presence || "AZ", inline: true },
          { name: "Source", value: source, inline: true }
        ],
        footer: { text: "Found #{Time.current.strftime('%m/%d %I:%M %p')}" }
      }
    end

    # Actually fires the HTTP POST to Discord, with the same 429-retry-once behavior the
    # Python version had (Discord tells you how long to wait via retry_after).
    def post_embed(embed)
      response = faraday.post(@webhook_url, { embeds: [ embed ] }.to_json, "Content-Type" => "application/json")

      if response.status == 429
        retry_after = JSON.parse(response.body)["retry_after"].to_f rescue 2.0
        sleep(retry_after + 0.5) unless Rails.env.test?
        response = faraday.post(@webhook_url, { embeds: [ embed ] }.to_json, "Content-Type" => "application/json")
      end

      response.status == 204
    rescue Faraday::Error
      # Network hiccups, timeouts, DNS failures — none of these should crash the scrape run.
      false
    end

    # Lazily builds a Faraday connection with a 10-second timeout, matching the Python
    # requests.post(..., timeout=10) call.
    def faraday
      @faraday ||= Faraday.new { |f| f.options.timeout = 10 }
    end
  end
end
