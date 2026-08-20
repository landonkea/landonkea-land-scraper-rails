# Mohave County publishes its own over-the-counter tax deed list as a PDF, with a
# different column layout than Cochise. Port of _mohave() from scraper.py.
module LandScraper
  class MohaveScraper
    SOURCE_NAME = "mohave_county"
    PDF_URL = "https://www.mohave.gov/media/2yjev04g/otc_td_list-0625.pdf"
    INFO_URL = "https://www.mohave.gov/departments/clerk-of-the-board/over-the-counter-tax-deed-sales/"

    def call
      pdf_bytes = HttpClient.get(PDF_URL, timeout_seconds: 30)
      return [] if pdf_bytes.nil?

      rows = PdfTableExtractor.extract_rows(pdf_bytes)
      rows.filter_map { |row| build_listing(row) }
    rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError
      []
    end

    private

    def build_listing(row)
      return nil if row.length < 8 || row[1].blank?

      parcel = row[1].to_s.strip
      return nil unless parcel.match?(/\A\d{6,8}/)

      owner = row[2].to_s.strip
      desc = row[3].to_s.strip
      location = row[4].to_s.strip
      fcv = clean_money(row[5])
      owed = clean_money(row[6])
      min_bid = clean_money(row[7])

      # Same fallback chain as the Python version: prefer an explicit minimum bid, then
      # fall back to whichever of full-cash-value / taxes-owed is smaller (or whichever exists).
      price =
        if min_bid.positive?
          min_bid
        elsif fcv.positive? && owed.positive?
          [ fcv, owed ].min
        else
          fcv.positive? ? fcv : owed
        end
      return nil unless price.positive?

      title = "Mohave County tax deed - #{desc[0, 50]} - #{location}"
      description = "Owner: #{owner}. Desc: #{desc}. Min bid: $#{format('%.0f', price)}"

      ListingBuilder.build(
        source: SOURCE_NAME,
        source_id: parcel,
        title: title,
        price: price,
        url: INFO_URL,
        location: location,
        description: description
      )
    end

    def clean_money(cell)
      Float(cell.to_s.gsub(/[$,\s]/, ""), exception: false) || 0
    end
  end
end
