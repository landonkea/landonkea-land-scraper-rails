# Maricopa County's excess-land page lists parcels as plain text blocks (not tidy cards),
# each one starting with "Assessor's Parcel Number:". This scraper grabs the whole
# rendered page's text and splits it on that marker, same technique _maricopa() used in
# the Python version.
module LandScraper
  class MaricopaScraper
    SOURCE_NAME = "maricopa_county"
    URL = "https://www.maricopa.gov/5325/Available-for-Sale"

    def initialize(browser)
      @browser = browser
    end

    def call
      text = @browser.page_text(URL, scroll_times: 5, scroll_pixels: 800)
      return [] if text.blank?

      # split(-1) keeps this simple: dropping the first chunk (page header, before any
      # parcel) via `[1..]`, same as parcels[1:] in the Python version.
      chunks = text.split(/Assessor's Parcel Number:/)[1..] || []
      chunks.filter_map { |chunk| build_listing(chunk) }
    end

    private

    def build_listing(chunk)
      lines = chunk.split("\n").map(&:strip).reject(&:empty?)
      return nil if lines.length < 3 # too short to be a real parcel entry

      parcel = lines.first
      location = ""
      size = ""
      min_bid = ""

      lines.each_with_index do |line, i|
        if line.start_with?("Location:")
          location = lines[i + 1] || ""
        elsif line.start_with?("Size:")
          size = lines[i + 1] || ""
        elsif line.include?("Minimum Bid:")
          min_bid = lines[i + 1] || ""
        end
      end

      price = min_bid[/\$([\d,]+)/, 1]&.delete(",")&.to_f || 0

      title = "Maricopa County excess land - #{size} - #{location}"
      description = "Size: #{size}. Min bid: #{min_bid}"

      ListingBuilder.build(
        source: SOURCE_NAME,
        source_id: parcel,
        title: title,
        price: price,
        url: URL,
        location: location,
        description: description
      )
    end
  end
end
