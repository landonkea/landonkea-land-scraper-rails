# This migration builds the "listings" table, the Rails equivalent of the "lands" table
# the Python version kept in SQLite. Every column here maps to something the original
# scraper.py / database.py pair tracked for each parcel of land it found.
class CreateListings < ActiveRecord::Migration[8.1]
  # Rails calls this method to build (or, on rollback, tear down) the table.
  def change
    # create_table opens a block where each `t.something` line adds one column.
    create_table :listings do |t|
      t.string :source                      # which scraper found this listing, e.g. "craigslist" or "cochise_county"
      t.string :source_id                   # the site's own id for the listing (a URL, parcel number, etc.) — this is what makes a listing unique per source
      t.string :title                       # the listing's headline, trimmed to 150 chars just like the Python version did
      t.decimal :price, precision: 12, scale: 2  # asking price / minimum bid in dollars; decimal avoids floating-point rounding weirdness with money
      t.string :url                         # link back to the original listing so a human can click through
      t.string :location                    # town/county/region text pulled from the page, not a strict geocoded address
      t.text :description                   # longer blurb used for scoring keywords, trimmed to 500 chars like the original
      t.integer :score, default: 0          # 0-100 score from the scoring rules in Filters — defaults to 0 so a blank score never breaks a sort
      t.datetime :first_seen_at             # timestamp for when we first saved this exact listing, used on the dashboard

      t.timestamps                          # adds created_at/updated_at, Rails' standard "when was this row touched" columns
    end

    # The Python schema had `UNIQUE(source, source_id)` so the same listing never gets
    # inserted twice. We reproduce that here with a composite unique index.
    add_index :listings, [ :source, :source_id ], unique: true
  end
end
