# Every scraper needs to do the same two things before a listing is worth saving: run it
# through Filters.should_skip? and, if it survives, give it a Filters.score_listing score.
# Pulling that into one helper keeps each individual scraper focused on "how do I find
# listings on this particular site" instead of repeating the filter/score dance nine times.
module LandScraper
  module ListingBuilder
    module_function

    # Returns a plain Hash ready to hand to Listing.create, or nil if the listing should
    # be thrown out. title/description get combined for the skip-check and the scoring,
    # same as every individual scraper function did in the Python version.
    def build(source:, source_id:, title:, price:, url:, location: "", description: "")
      return nil if Filters.should_skip?(title, description)

      score = Filters.score_listing(title, description, price)

      {
        source: source,
        source_id: source_id,
        title: title,
        price: price,
        url: url,
        location: location,
        description: description,
        score: score
      }
    end
  end
end
