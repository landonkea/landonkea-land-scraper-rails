# Cochise County publishes its tax-deed land sale list as a PDF table. Port of
# _cochise() from scraper.py — download the PDF, pull rows out of it, and read off the
# same columns the Python version used (unit ID, zoning, acreage, legal description,
# owner, full cash value, minimum bid).
module LandScraper
  class CochiseScraper
    SOURCE_NAME = "cochise_county"
    PDF_URL = "https://www.cochise.az.gov/DocumentCenter/View/26715/Spring-2026-Tax-Deed-Land-Sale-Parcel-Listing-PDF"
    INFO_URL = "https://www.cochise.az.gov/811/2026-Tax-Deed-Land-Sale"

    def call
      pdf_bytes = HttpClient.get(PDF_URL, timeout_seconds: 30)
      return [] if pdf_bytes.nil?

      rows = PdfTableExtractor.extract_rows(pdf_bytes)
      rows.filter_map { |row| build_listing(row) }
    rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError
      # A PDF that changed shape or won't parse just means Cochise contributes nothing
      # this run — same as the Python version's bare `except: return 0`.
      []
    end

    private

    def build_listing(row)
      return nil if row.length < 9 || row[1].blank?

      unit_id = row[1].to_s.strip
      return nil unless unit_id.match?(/\A\d{6,8}/) # real unit IDs are 6-8 digits; anything else is a header/garbage row

      zoning = row[2].to_s.strip
      acreage = Float(row[3], exception: false)
      return nil unless acreage

      legal_desc = row[4].to_s.strip
      fcv = clean_money(row[6])
      min_bid = clean_money(row[8])
      price = min_bid.positive? ? min_bid : fcv
      return nil unless price.positive?

      # Legal descriptions read like "APN 123-45-678, LOT 1, BLOCK 2..." — everything
      # before the first LOT/BLOCK/BLK/TR marker is the actual location.
      location_match = legal_desc.match(/(.+?)(?:LOT|BLOCK|BLK|TR)/i)
      location = (location_match ? location_match[1] : legal_desc[0, 60]).to_s.strip.delete_suffix(",")

      title = "Cochise County tax deed - #{acreage} acres - #{location}"
      description = "Zoning: #{zoning}. #{acreage}ac. Min bid: $#{format('%.0f', price)}"

      ListingBuilder.build(
        source: SOURCE_NAME,
        source_id: unit_id,
        title: title,
        price: price,
        url: INFO_URL,
        location: location,
        description: description
      )
    end

    # Strips $ , and spaces out of a money-ish cell and parses it, defaulting to 0 for
    # blank/garbled values — same fallback behavior as the Python try/except blocks.
    def clean_money(cell)
      Float(cell.to_s.gsub(/[$,\s]/, ""), exception: false) || 0
    end
  end
end
