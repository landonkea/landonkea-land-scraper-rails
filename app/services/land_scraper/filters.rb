# This module is a straight port of the Python project's filters.py. It decides which
# listings are junk (should_skip?) and rates the ones that survive (score_listing), using
# the exact same keyword lists and point values the original used — nothing here is
# reinvented, it's the same rules translated from Python regex into Ruby regex.
module LandScraper
  module Filters
    # module_function turns every method below into both a module-level method
    # (LandScraper::Filters.should_skip?) and a private instance method if this module
    # ever gets `include`d somewhere — we only actually use the module-level form.
    module_function

    # Catches listings that aren't really land for sale at all: rentals, storage units,
    # RV parks, age-restricted communities, HOA-fee traps, unbuildable lots, and so on.
    # This is one big regex because that's how the Python version wrote it — a single
    # SKIP pattern with every red-flag phrase joined by "|" (meaning "or").
    SKIP = /for rent|for lease|room|roommate|parking|storage|mobile home park| rv |rv lot|camper|vacation rental|airbnb|vrbo|rent to own|rental|yearly rental|winter rental|rent this|monthly rent|per month|\/mo|\/year|annaul rental|sale or rent|or rent|free rent|paying.*rent|55 plus|55\+|senior community|senior park|retirement community|age.restricted|adult community|senior living|age 55|ages 55|55 years|55 community|55 park|active adult|lot rent|lot fee|lot fees|park rent|park fee|park fees|lot lease|lot leases|monthly fee|monthly dues|ground rent|space rent|space fee|maintenance fee|maintenance dues|site rent|site fee|annual fee|annual dues|annual assessment|yearly fee|yearly dues|yearly assessment|road maintenance|road fee|road assessment|utility fee|utility charge|utility assessment|club fee|club dues|amenity fee|amenity dues|golf fee|golf dues|special assessment|sewer fee|sewer charge|water fee|water charge|sewer assessment|water assessment|rv park|rv resort|rv community|camper park|campground|trailer park|manufactured home community|manufactured housing|commercial only|industrial only|agricultural only|ag only|speedway|raceway|racetrack|race track|gravel pit|quarry|mine adjacent|mining adjacent|city limits|within city|inside city|wetland|unbuildable|cannot build|no build|no construction|shared easement|power line easement|utility easement|easement crossing|brownfield|toxic|hazardous waste|contaminated|landfill adjacent/i

    # "Deed restriction" on its own is bad news (limits what you can build/do), so it's a skip trigger...
    DEED = /deed restriction/i
    # ...unless the listing specifically says "no deed restrictions", which is actually a selling point.
    NO_DEED = /no\s*deed\s*restriction/i

    # Flood zones mean expensive insurance and building headaches, always a skip.
    FLOOD = /flood zone|floodplain|flood plain|flood insurance|fema flood|100-year flood/i

    # No legal way to reach the property means it's practically worthless to us.
    LOCKED = /landlocked|no road access|no easement|no legal access/i

    # Phrases that say a property is free of HOA dues/covenants — this is a green flag.
    NO_HOA = /no\s*hoa|no\s*homeowners\s*assoc|no\s*restrictions|unrestricted|no\s*cc&r|no\s*cc\s*and\s*r|no\s*dues/i
    # Mentions of an actual HOA (fees, CC&Rs) without the "no" qualifier above — a skip trigger.
    HOA = /hoa\b|homeowners association|hoa fees|hoa dues|cc&r|cc and r/i

    # Ground leases and lease-only deals mean you never actually own the dirt — skip.
    LEASE = /lease only|for lease|leasing only|ground lease|sublease/i

    # Liens and distressed-sale language mean legal complications on top of the land itself.
    LIEN = /tax lien|government lien|irs lien|bank owned|reo|short sale|lis pendens/i

    # --- Everything below here feeds into the score instead of an outright skip ---

    PAVED = /paved road|paved access|asphalt|highway frontage|state road/i
    ELECTRIC = /electric|power|electricity|pg&e|aps|srp|utility pole|grid power/i
    MOBILE = /mobile home allowed|manufactured home|mobile permitted|manufactured ok|single wide|double wide|factory built/i
    RV = /rv allowed|rv parking|rv ok|camper allowed|rv permitted|rv friendly|live in rv|camping allowed/i
    PUBLIC = /adjacent to public|bordering public|next to national forest|near blm|near forest|backs to public/i
    TAX = /low tax|low property tax|minimal tax|no property tax/i
    CELL = /cell service|cell coverage|cell signal|verizon|at&t|t-mobile/i
    # Grab-bag of generally good land features — road access, utilities, mineral/water rights, a flat buildable lot.
    GOOD = /acreage|acres|utilities|road access|gated|fenced|mountain view|river|creek|spring|mineral rights|water rights|no hoa|no restrictions|unrestricted|well|septic|perc test|buildable|level lot|flat land|surveyed|corner lot/i
    # An existing water well is the single biggest value-add on remote land — separate, bigger bonus.
    HIGH = /water well|well on property|existing well|well drilled|well permit|well rights|well with pump/i
    # Owner/seller financing means we can buy without going through a bank.
    CARRY = /owner will carry|owner financing|seller financing|owner carry|seller will carry|terms available|flexible terms|low down|easy terms|owner financed|seller financed/i

    # Arizona towns the buyer actually wants to be near — matching one of these earns a small bonus.
    PREFERRED_AREAS = %w[prescott sedona verde\ valley cottle camp\ verde cottonwood clarkdale jerome chino\ valley williams].freeze

    # Tries to pull a lot size out of free text, preferring an explicit acreage figure
    # ("5 acres", "2.5 ac") and falling back to square footage ("12,500 sq ft") converted
    # to acres if that's all the listing gives us. Returns nil if neither pattern matches.
    def parse_acres(text)
      downcased = text.to_s.downcase
      # \b after the unit stops this from matching partway into a longer word.
      if (m = downcased.match(/([\d,.]+)\s*(?:acres?|ac\.?)\b/))
        return m[1].delete(",").to_f
      end
      # 43,560 square feet is exactly one acre — same conversion factor the Python version used.
      if (m = downcased.match(/([\d,.]+)\s*(?:sq\.?\s*ft|sqft|square\s*feet)/))
        return m[1].delete(",").to_f / 43_560
      end
      nil
    end

    # Returns true if a listing should be thrown out entirely before we even bother scoring it.
    def should_skip?(title, text = "")
      combined = "#{title} #{text}"
      # Any of these outright disqualifying patterns matching is an instant skip.
      return true if [ SKIP, FLOOD, LOCKED, LEASE, LIEN ].any? { |pattern| pattern.match?(combined) }
      # HOA mentions are bad UNLESS the listing is specifically saying there's no HOA.
      return true if HOA.match?(combined) && !NO_HOA.match?(combined)
      # Same logic for deed restrictions: bad unless explicitly denied.
      return true if DEED.match?(combined) && !NO_DEED.match?(combined)
      # Tiny slivers of land (under a fifth of an acre) usually aren't buildable or useful.
      acres = parse_acres(combined)
      return true if acres && acres < 0.2
      false
    end

    # Scores a listing from 0-100. Higher means a more promising deal. This point scheme
    # is copied value-for-value from score_listing() in the Python filters.py — the goal
    # here is fidelity to the original ranking, not a "better" algorithm.
    def score_listing(title, text = "", price = 0)
      combined = "#{title} #{text}".downcase
      score = 40 # every listing starts at a baseline of 40 points
      score += 35 if HIGH.match?(combined)   # an existing well is the single best feature you can find
      score += 25 if CARRY.match?(combined)  # owner financing opens the deal up to buyers without bank loans
      # Tax-deed / tax-sale / OTC / redemption language usually means the cheapest possible way to buy land.
      score += 20 if combined.match?(/tax deed|tax sale|over.the.counter|otc|redemption/)
      score += 10 if NO_HOA.match?(combined)
      score += 10 if PAVED.match?(combined)
      score += 8  if ELECTRIC.match?(combined)
      score += 10 if MOBILE.match?(combined)
      score += 8  if RV.match?(combined)
      score += 10 if PUBLIC.match?(combined)
      score += 5  if TAX.match?(combined)
      score += 5  if CELL.match?(combined)
      score += 10 if GOOD.match?(combined)

      if price.to_f > 0
        # Cheaper listings get a bigger flat bonus, in three tiers, same cutoffs as the original.
        if price < 5_000
          score += 15
        elsif price < 15_000
          score += 10
        elsif price < 30_000
          score += 5
        end
      end

      acres = parse_acres(combined)
      # Price-per-acre only makes sense once we actually know both numbers, and only for
      # parcels above the same 0.2-acre floor used in should_skip?.
      if acres && acres >= 0.2 && price.to_f > 0
        price_per_acre = price.to_f / acres
        if price_per_acre < 1_000
          score += 20
        elsif price_per_acre < 2_500
          score += 15
        elsif price_per_acre < 5_000
          score += 10
        elsif price_per_acre < 10_000
          score += 5
        end
      end

      # Small bonus for being in one of the towns we're actually hoping to find land near.
      score += 5 if PREFERRED_AREAS.any? { |area| combined.include?(area) }

      # Clamp the final number to the 0-100 range, no negatives or overflow.
      [ [ score, 0 ].max, 100 ].min
    end
  end
end
