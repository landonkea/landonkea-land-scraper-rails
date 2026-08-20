# Base class for the three sites that all follow the same shape: load a JS-rendered page,
# pull out {href, text} pairs for each listing "card" via a site-specific CSS selector,
# then parse a price and title out of that text. This is the Ruby equivalent of the
# generic _pw_scrape() helper in the Python scraper.py, which Landmodo, GoV Auctions, and
# Land Zero all called with their own custom JS. Subclasses just set SOURCE_NAME, URL, and CARD_JS.
module LandScraper
  class CardScraper
    def initialize(browser)
      @browser = browser
    end

    def call
      cards = @browser.scrape(self.class::URL, self.class::CARD_JS)
      return [] unless cards.is_a?(Array)

      Rails.logger.info("[LandScraper] #{self.class::SOURCE_NAME}: scanning #{cards.size} cards")
      cards.filter_map { |card| build_listing(card) }
    end

    private

    def build_listing(card)
      href = card["href"].to_s
      text = card["text"].to_s
      price_match = text[/\$([\d,]+)/, 1]
      return nil unless price_match # no dollar amount on the card means we can't evaluate it

      price = price_match.delete(",").to_f
      lines = text.split("\n").map(&:strip).reject(&:empty?)
      # Picks the first line that looks like an actual title: longer than 10 chars, not
      # the price line itself, not a "Posted ..." timestamp line — same heuristic the
      # Python _pw_scrape() used.
      title = lines.find { |line| line.length > 10 && !line.include?("$") && !line.include?("Posted") } || lines.first || "Land listing"

      ListingBuilder.build(
        source: self.class::SOURCE_NAME,
        source_id: href,
        title: title,
        price: price,
        url: href,
        location: "",
        description: text[0, 500]
      )
    end
  end
end
