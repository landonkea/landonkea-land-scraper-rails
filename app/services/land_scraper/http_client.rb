# A tiny shared wrapper around Faraday so every plain-HTTP scraper (Craigslist, ADOT, and
# the county PDF scrapers) sends the same fake browser User-Agent the Python version used —
# some of these sites reject requests that don't look like they came from a real browser.
module LandScraper
  class HttpClient
    # Same string requests.get(headers=...) used in scraper.py, byte for byte.
    USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"

    # Fetches a URL and returns the raw response body as a string, or nil if anything
    # went wrong (timeout, DNS failure, non-200 status). timeout_seconds defaults to 15,
    # matching the Craigslist/ADOT calls; the PDF scrapers pass 30 since PDFs are bigger.
    def self.get(url, timeout_seconds: 15, params: nil)
      connection = Faraday.new { |f| f.options.timeout = timeout_seconds }
      response = connection.get(url, params, "User-Agent" => USER_AGENT)
      response.success? ? response.body : nil
    rescue Faraday::Error
      # Any network-level failure just means "this source didn't come back today" —
      # the original Python scrapers all silently swallowed these too (bare `except: pass`).
      nil
    end
  end
end
