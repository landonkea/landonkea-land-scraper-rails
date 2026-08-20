# Arizona Department of Transportation posts a static (no-JS-needed) page listing surplus
# right-of-way land. Port of _adot() from scraper.py — a plain HTTP fetch, then regex
# parsing of the page's visible text, which is laid out as repeating "Excess Land No."
# blocks.
module LandScraper
  class AdotScraper
    SOURCE_NAME = "adot"
    URL = "https://azdot.gov/business/right-way-properties/vacant-land-and-commercial-properties-sale"
    STATUS_VALUES = [ "IN ESCROW", "OFFER TENDERED", "PRICE REDUCED" ].freeze

    def call
      html = HttpClient.get(URL, timeout_seconds: 20)
      return [] if html.nil?

      # Nokogiri's #text pulls every visible string node out of the page in document
      # order, joined together — same as BeautifulSoup's soup.get_text('\n') call, except
      # we join with newlines ourselves so the line-based parsing below still works.
      text = Nokogiri::HTML(html).css("body").text
      chunks = text.split(/\nExcess Land No\.\n/)[1..] || text.split(/Excess Land No\./)[1..] || []
      chunks.filter_map { |chunk| build_listing(chunk) }
    end

    private

    def build_listing(chunk)
      lines = chunk.split("\n").map(&:strip).reject(&:empty?)
      return nil if lines.length < 3

      land_id = lines.first
      location = ""
      size = ""
      min_bid = ""
      price = 0
      status = ""

      lines.each_with_index do |line, i|
        if line == "Location" && lines[i + 1]
          location = lines[i + 1]
        elsif line.match?(/\d[\d,]*\s*sq\s*ft/)
          size = line
        elsif line.include?("Minimum Bid:")
          if (m = line.match(/\$([\d,]+)/))
            min_bid = m[0]
            price = m[1].delete(",").to_f
          end
        elsif STATUS_VALUES.include?(line)
          status = line
        end
      end

      return nil if min_bid.blank? # no bid amount means the listing is incomplete or already gone

      title = "ADOT excess land #{land_id} - #{size} - #{location}"
      title += " [#{status}]" if status.present?
      description = "Size: #{size}. Min bid: #{min_bid}. #{status}"

      ListingBuilder.build(
        source: SOURCE_NAME,
        source_id: land_id,
        title: title,
        price: price,
        url: URL,
        location: location,
        description: description
      )
    end
  end
end
