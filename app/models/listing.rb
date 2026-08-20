# A Listing is one parcel of land found by one of the scrapers in app/services/land_scraper.
# This is the Rails equivalent of a row in the Python version's "lands" SQLite table.
class Listing < ApplicationRecord
  # Every listing needs to at least have a source name (which scraper found it) and a
  # source_id (the site's own identifier), because those two together are what stop us
  # from saving the same parcel twice — same rule the Python UNIQUE(source, source_id) enforced.
  validates :source, presence: true
  validates :source_id, presence: true
  # The database-level unique index backs this up, but validating here gives a friendly
  # Rails error instead of a raw SQLite exception if something ever tries to double-save.
  validates :source_id, uniqueness: { scope: :source }

  # "Good" listings are the ones worth a human's attention — the Python get_stats()
  # function used the same >= 50 cutoff when counting "good" listings for the console summary.
  GOOD_SCORE_THRESHOLD = 50

  # scope is a reusable, chainable query — this one hands back only the listings that
  # cleared the "good" bar, letting the dashboard filter without repeating the SQL everywhere.
  scope :good, -> { where("score >= ?", GOOD_SCORE_THRESHOLD) }

  # Sorts highest score first, then cheapest price first as the tiebreaker — this mirrors
  # the exact ORDER BY the Python get_top_listings() query used.
  scope :best_first, -> { order(score: :desc, price: :asc) }

  # Lets the dashboard narrow the list down to one source (e.g. only "craigslist" rows)
  # without the controller needing to know anything about how the query is built.
  scope :from_source, ->(source) { where(source: source) if source.present? }

  # Handy for the dashboard's price filter — only show listings at or under some ceiling.
  scope :under_price, ->(max) { where(price: ..max) if max.present? }

  # True once a listing's score clears the "good" bar; used in views so the threshold
  # logic lives in one place instead of being copy-pasted into ERB templates.
  def good?
    score.to_i >= GOOD_SCORE_THRESHOLD
  end
end
