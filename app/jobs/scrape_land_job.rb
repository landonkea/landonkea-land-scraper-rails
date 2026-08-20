# This is the job Solid Queue runs on a schedule (see config/recurring.yml). It's the
# Ruby equivalent of main.py: wipe out yesterday's listings, run every scraper, log a
# quick summary, and save a daily history snapshot.
class ScrapeLandJob < ApplicationJob
  # "default" is the plain built-in Solid Queue queue — this job doesn't need its own
  # dedicated queue since only one scrape should ever run at a time anyway.
  queue_as :default

  def perform
    Rails.logger.info("[LandScraper] scrape starting #{Time.current} — south Flagstaff, north Tucson")

    # The Python version wiped its whole "lands" table at the start of every run
    # (clear_old) so the table only ever reflects the latest scrape, not an accumulating
    # history — we do the same here for the same reason: stale listings shouldn't linger.
    Listing.delete_all

    saved = LandScraper::Runner.new.call

    total = Listing.count
    good = Listing.good.count
    Rails.logger.info("[LandScraper] new: #{saved} | db: #{total} total, #{good} good (>=50)")

    # Snapshot today's numbers for the dashboard's trend view, same job history.py did.
    LandScraper::HistorySnapshot.save

    Rails.logger.info("[LandScraper] scrape finished #{Time.current}")
  end
end
