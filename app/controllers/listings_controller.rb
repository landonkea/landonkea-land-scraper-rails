# The dashboard controller — one page showing whatever land listings are currently in
# the database, best-scoring first, with a couple of simple filters.
class ListingsController < ApplicationController
  # index is the only action this app needs: one page, no create/edit/delete, since
  # listings only ever come in through the scrape job, never through a form.
  def index
    # best_first is the Listing scope that orders by score desc then price asc —
    # same ordering the Python get_top_listings() query used.
    scope = Listing.best_first
    # from_source/under_price are no-ops (return the full scope) when the param is blank,
    # so leaving either filter empty on the page just shows everything.
    scope = scope.from_source(params[:source])
    scope = scope.under_price(params[:max_price])
    @listings = scope

    # Populates the source dropdown with whatever sources actually exist right now,
    # instead of a hardcoded list that would drift out of sync with the real scrapers.
    @sources = Listing.distinct.order(:source).pluck(:source)

    # A little header strip showing total/good counts and when the last scrape ran,
    # pulled straight off the listings table rather than re-querying DailySummary.
    @total_count = Listing.count
    @good_count = Listing.good.count
    @last_scraped_at = Listing.maximum(:first_seen_at)
  end
end
