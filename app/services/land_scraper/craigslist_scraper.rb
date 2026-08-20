# Scrapes Craigslist's real-estate search results for a handful of Arizona regions.
# This is the fastest scraper of the bunch because Craigslist's search page is plain
# server-rendered HTML — no browser needed, just an HTTP GET and Nokogiri. Direct port
# of _cl() from the Python scraper.py.
module LandScraper
  class CraigslistScraper
    # Same four Craigslist subdomains the Python CRAIGSLIST_REGIONS list covered.
    REGIONS = %w[phoenix prescott flagstaff yuma].freeze
    # /rea is Craigslist's path for the real estate category.
    LAND_PATH = "/rea"

    # Runs the scrape and returns an array of listing-attribute Hashes (already filtered
    # and scored via ListingBuilder) ready for the Runner to save.
    def call
      REGIONS.flat_map { |region| scrape_region(region) }
    end

    private

    def scrape_region(region)
      html = HttpClient.get("https://#{region}.craigslist.org/search#{LAND_PATH}", timeout_seconds: 15)
      # A failed request (nil body) just means this region contributes nothing this run —
      # matches the Python version's bare `except: pass` around the whole region loop.
      return [] if html.nil?

      Nokogiri::HTML(html).css("li.cl-static-search-result").filter_map { |row| build_listing(region, row) }
    end

    # Turns one <li class="cl-static-search-result"> row into a listing Hash, or nil if
    # it's missing a link or gets filtered out by should_skip?.
    def build_listing(region, row)
      link = row.at_css("a[href]")
      return nil unless link

      href = link["href"]
      href = "https://#{region}.craigslist.org#{href}" unless href.start_with?("http")

      title = row.at_css("div.title")&.text&.strip.to_s
      price_text = row.at_css("div.price")&.text&.strip.to_s
      price = price_text[/\$([\d,]+)/, 1]&.delete(",")&.to_f || 0
      location = row.at_css("div.location")&.text&.strip.presence || region

      ListingBuilder.build(
        source: "craigslist",
        source_id: href,
        title: title,
        price: price,
        url: href,
        location: location,
        # Craigslist's search results don't show the listing body, so there's no description text to score against — same gap the Python version had.
        description: ""
      )
    end
  end
end
