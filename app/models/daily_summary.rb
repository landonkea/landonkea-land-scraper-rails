# A DailySummary is one day's worth of stats about the listings table, written once per
# scrape run. This is the Rails equivalent of one entry appended to the Python version's
# docs/data/history.json file by history.py.
class DailySummary < ApplicationRecord
  # Every snapshot needs a date so we know which day it describes, and the date has to be
  # unique because the job only ever writes one summary per day (backed by the DB index too).
  validates :summary_date, presence: true, uniqueness: true

  # by_source is stored as a plain text column (SQLite has no dedicated JSON type in this
  # setup), so we serialize a Ruby Hash to JSON going in and parse it back coming out.
  # `coder: JSON` tells ActiveRecord to run our values through the JSON library automatically.
  serialize :by_source, coder: JSON

  # Oldest-to-newest by default, which is the natural order for drawing a trend line later.
  default_scope { order(:summary_date) }
end
