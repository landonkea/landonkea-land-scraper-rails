# Pinal County publishes its over-the-counter state tax deed list as a PDF too, with a
# simpler 4-column layout: parcel number, owner name, legal description, amount. Port of
# _pinal() from scraper.py.
module LandScraper
  class PinalScraper
    SOURCE_NAME = "pinal_county"
    PDF_URL = "https://treasurer.pinal.gov/downloads/Over%20The%20Counter%20State%20Tax%20Deed%20List%20July%202026.pdf"
    INFO_URL = "https://treasurer.pinal.gov/special-districts.aspx"

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
      return nil if row.length < 4 || row[0].blank?

      parcel = row[0].to_s.strip
      # Pinal formats parcel numbers as 123-45-678; anything else in column 0 is a header row.
      return nil unless parcel.match?(/\A\d{3}-\d{2}-\d{3}/)

      name = row[1].to_s.strip
      legals = row[2].to_s.strip
      price = Float(row[3].to_s.gsub(/[$,]/, "").strip, exception: false) || 0
      return nil unless price.positive?

      title = "Pinal County tax deed - #{legals[0, 50]}"
      description = "Owner: #{name}. Desc: #{legals}. Bid: $#{format('%.0f', price)}"

      ListingBuilder.build(
        source: SOURCE_NAME,
        source_id: parcel,
        title: title,
        price: price,
        url: INFO_URL,
        location: "Pinal County",
        description: description
      )
    end
  end
end
