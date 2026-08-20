# Orchestrates every individual scraper, saves whatever they find, and sends Discord
# alerts for the good ones once everything is done. This is the Ruby equivalent of
# scrape_all() in the Python scraper.py — same order of sources, same "collect alerts,
# sort cheapest-first, then send" behavior at the end.
module LandScraper
  class Runner
    # Only listings scoring 40 or above get a Discord alert — matches the `if sc >= 40`
    # check repeated after every single save() call in the Python version.
    ALERT_SCORE_THRESHOLD = 40

    def initialize(notifier: DiscordNotifier.new)
      @notifier = notifier
      @alerts = [] # holds attribute hashes for every alert-worthy listing, sent only after everything's saved
      @saved_count = 0
    end

    # Runs every scraper in turn, saves new listings, and fires off Discord alerts
    # cheapest-first at the end. Returns the total number of new rows saved.
    def call
      # Craigslist goes first since it's the cheapest scraper to run (plain HTTP, no browser).
      run(LandScraper::CraigslistScraper.new)

      # Everything below needs a real rendered browser, so we launch Chrome once and
      # share it across all four JS-heavy sources, then always shut it down.
      browser = LandScraper::Browser.new
      begin
        run(LandScraper::LandmodoScraper.new(browser))
        run(LandScraper::GovAuctionsScraper.new(browser))
        run(LandScraper::LandZeroScraper.new(browser))
        run(LandScraper::MaricopaScraper.new(browser))
      ensure
        browser.quit
      end

      # These five are all plain HTTP (static pages or PDFs), no browser needed.
      run(LandScraper::AdotScraper.new)
      run(LandScraper::CochiseScraper.new)
      run(LandScraper::MohaveScraper.new)
      run(LandScraper::YavapaiScraper.new)
      run(LandScraper::PinalScraper.new)

      send_alerts
      @saved_count
    end

    private

    # Runs one scraper, saves whatever it finds, and queues up alerts for the good ones.
    # A scraper raising an exception doesn't take down the whole run — one bad source
    # shouldn't stop the others, same spirit as every bare `except: pass` in the Python code.
    def run(scraper)
      listings = scraper.call
      new_count = 0

      listings.each do |attrs|
        if save(attrs)
          new_count += 1
          @alerts << attrs if attrs[:score].to_i >= ALERT_SCORE_THRESHOLD
        end
      end

      @saved_count += new_count
      Rails.logger.info("[LandScraper] #{scraper.class.name.demodulize.underscore}: +#{new_count}")
    rescue StandardError => e
      Rails.logger.error("[LandScraper] #{scraper.class.name} failed: #{e.class}: #{e.message}")
    end

    # Inserts one listing, trimming title/description to the same lengths the Python
    # database.py used. Returns true only if this is a genuinely new row — a duplicate
    # (same source + source_id, which can't happen within a run since the table gets
    # wiped before scraping starts, but could in theory if two scrapers overlap) is
    # silently ignored, same as SQLite's INSERT OR IGNORE.
    def save(attrs)
      listing = Listing.new(
        source: attrs[:source],
        source_id: attrs[:source_id],
        title: attrs[:title].to_s[0, 150],
        price: attrs[:price],
        url: attrs[:url],
        location: attrs[:location],
        description: attrs[:description].to_s[0, 500],
        score: attrs[:score],
        first_seen_at: Time.current
      )
      listing.save
    rescue ActiveRecord::RecordNotUnique
      false
    end

    # Cheapest listings first, matching `alerts.sort(key=lambda a: a[0])` in the Python
    # version (a[0] was price in that tuple).
    def send_alerts
      @alerts.sort_by { |a| a[:price].to_f }.each do |a|
        @notifier.send_alert(
          title: a[:title], price: a[:price], url: a[:url],
          location: a[:location], score: a[:score], source: a[:source]
        )
      end
    end
  end
end
