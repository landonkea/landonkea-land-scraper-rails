# Yavapai County's PDF isn't a clean table like the other three counties — it's a
# repeating block of labeled text ("Former Owner - NAME", "Parcel Number - XXX-XX-XXX",
# etc.), so this one parses plain extracted text with regexes instead of going through
# PdfTableExtractor. It also cross-references each parcel against Yavapai's public ArcGIS
# API to fill in subdivision name, street address, and acreage. Port of _yavapai() from
# scraper.py.
module LandScraper
  class YavapaiScraper
    SOURCE_NAME = "yavapai_county"
    PDF_URL = "https://www.yavapaiaz.gov/files/sharedassets/public/v/1/mapping-and-properties/parcelsforsaleundertaxdeedsale-04022025-2.pdf"
    INFO_URL = "https://www.yavapaiaz.gov/Mapping-and-Properties/Property-Taxes/Tax-Deed-Sales"
    GIS_URL = "https://services1.arcgis.com/BajuNXbtZNiBKFkx/arcgis/rest/services/Parcels_in_Yavapai_County/FeatureServer/0/query"

    def call
      pdf_bytes = HttpClient.get(PDF_URL, timeout_seconds: 30)
      return [] if pdf_bytes.nil?

      full_text = extract_text(pdf_bytes)
      # Splitting with a lookahead keeps the "Former Owner" marker attached to the start
      # of each block, same as Python's re.split(r'(?=Former Owner\s*[-–])', full_text).
      blocks = full_text.split(/(?=Former Owner\s*[-–])/)
      blocks.filter_map { |block| build_listing(block) }
    rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError
      []
    end

    private

    def extract_text(pdf_bytes)
      PDF::Reader.new(StringIO.new(pdf_bytes)).pages.map { |page| page.text.to_s }.join("\n")
    end

    def build_listing(block)
      return nil if block.strip.empty?

      parcel_match = block.match(/Parcel Number\s*[-–]\s*(\S+)/)
      return nil unless parcel_match

      owner_match = block.match(/Former Owner\s*[-–]\s*(.+)/)
      desc_match = block.match(/Partial Description:\s*(.+?)(?:\n|Redemption|Amount)/m)
      amount_match = block.match(/(?:Redemption Amount|Amount)\s*[-–]\s*\$?([\d,]+\.?\d*)/)

      parcel = parcel_match[1].strip
      owner = owner_match ? owner_match[1].strip : "Unknown"
      desc = desc_match ? desc_match[1].strip : ""
      price = amount_match ? amount_match[1].delete(",").to_f : 0
      return nil unless price.positive?

      gis = lookup_gis(parcel)
      subdivision = gis[:subdivision]
      address = gis[:address]
      acres = gis[:acres]

      location = [ subdivision, address, "Yavapai County" ].reject(&:blank?).join(", ")
      title =
        if subdivision.present?
          "#{subdivision} - Yavapai tax deed - #{desc[0, 40]}"
        else
          "Yavapai County tax deed - #{desc[0, 50]}"
        end

      detail_parts = [ "Owner: #{owner}", "Desc: #{desc}" ]
      detail_parts << "Subdivision: #{subdivision}" if subdivision.present?
      detail_parts << "Address: #{address}" if address.present?
      detail_parts << "Size: #{acres} acres" if acres.positive?
      detail_parts << "Redemption: $#{format('%.0f', price)}"

      ListingBuilder.build(
        source: SOURCE_NAME,
        source_id: parcel,
        title: title,
        price: price,
        url: INFO_URL,
        location: location,
        description: detail_parts.join(". ")
      )
    end

    # Looks up subdivision name, street address, and lot size for one parcel via
    # Yavapai's public ArcGIS feature service. Any failure here (bad network, no match)
    # just leaves those fields blank, same as the Python version's bare `except: pass`.
    def lookup_gis(parcel)
      response = Faraday.new { |f| f.options.timeout = 10 }.get(GIS_URL, {
        where: "PARLABEL='#{parcel}'",
        outFields: "SUBNAME,SITUS_ADD_DOR,Shape__Area",
        f: "json"
      })
      data = JSON.parse(response.body)
      feature = data.dig("features", 0, "attributes")
      return { subdivision: "", address: "", acres: 0 } unless feature

      area_sqft = feature["Shape__Area"].to_f
      {
        subdivision: feature["SUBNAME"].to_s,
        address: feature["SITUS_ADD_DOR"].to_s.strip,
        acres: area_sqft.positive? ? (area_sqft / 43_560).round(2) : 0
      }
    rescue Faraday::Error, JSON::ParserError
      { subdivision: "", address: "", acres: 0 }
    end
  end
end
