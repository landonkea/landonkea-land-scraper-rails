# Land Scraper (Rails)

This app looks for cheap land for sale in Arizona and tells you about the good ones on Discord. It's a Rails rewrite of a Python script that did the same job — same scoring rules, same list of sites, same idea, just running inside a real web app instead of a script you run from the command line.

## What it actually does

Once a day (or whenever you trigger it manually), a background job:

1. Wipes out yesterday's list of listings so the app never shows stale data.
2. Visits nine different sources — Craigslist, Landmodo, GoV Auctions, Land Zero, Maricopa County's surplus-land page, ADOT's vacant-land page, and PDF tax-deed lists from Cochise, Mohave, Yavapai, and Pinal counties.
3. Throws out anything that isn't really raw land for sale — rentals, HOA communities, flood zones, landlocked parcels, lots under a fifth of an acre.
4. Scores everything that's left, from 0 to 100, based on things like an existing water well, owner financing, no HOA, paved road access, and price per acre.
5. Saves the results to a database table and posts the promising ones (score 40+, under $100,000) to a Discord channel, cheapest first.
6. Records a one-line daily summary (total listings, how many scored well, average price) so you can see trends over time.

You look at the results on a plain web page: a table of every current listing, sorted best-score-first, with a couple of filters.

## How the pieces fit together

If you've never read Rails code before, here's a map. Everything lives under `app/`.

- **`app/models/listing.rb`** — one row per parcel of land. Holds the price, location, score, and a link back to the original listing.
- **`app/models/daily_summary.rb`** — one row per day the scraper has run, with that day's stats.
- **`app/services/land_scraper/`** — this is where the actual scraping logic lives, and it's the biggest chunk of the app:
  - `filters.rb` — the rules for what to skip and how to score a listing. This is copied point-for-point from the original Python version so a listing gets the same score either way.
  - `craigslist_scraper.rb`, `adot_scraper.rb` — sites that serve plain HTML, so these just make an HTTP request and pick data out of the page with Nokogiri (a library for reading HTML).
  - `landmodo_scraper.rb`, `gov_auctions_scraper.rb`, `land_zero_scraper.rb`, `maricopa_scraper.rb` — sites that build their listings with JavaScript in the browser, so these drive an actual headless Chrome browser (via a gem called Ferrum) to load the page first, the same way the Python version used Playwright.
  - `cochise_scraper.rb`, `mohave_scraper.rb`, `pinal_scraper.rb`, `yavapai_scraper.rb` — county tax-deed lists that only exist as PDFs. These download the PDF and pull the rows back out of it.
  - `pdf_table_extractor.rb` — a small helper the three table-shaped county PDFs share, for turning a page of PDF text back into rows and columns.
  - `runner.rb` — runs every scraper above in order, saves what they find, and sends the Discord alerts once everything is done.
  - `discord_notifier.rb` — builds and sends one Discord message for one listing.
  - `history_snapshot.rb` — writes the daily summary row.
- **`app/jobs/scrape_land_job.rb`** — the entry point. This is what actually gets run on a schedule; it calls everything above in the right order.
- **`app/controllers/listings_controller.rb`** and **`app/views/listings/index.html.erb`** — the one dashboard page.
- **`config/recurring.yml`** — tells Rails' built-in job scheduler (Solid Queue) to run the scrape job automatically, once a day.

## Running it locally

You'll need Ruby 3.4.9 and the gems this app depends on.

```
bundle install
bin/rails db:setup      # creates the database and runs the migrations
bin/dev                 # starts the web server and the Tailwind CSS watcher together
```

Then open `http://localhost:3000` in a browser. You'll see an empty dashboard until you actually run the scrape job once:

```
bin/rails runner "ScrapeLandJob.perform_now"
```

That kicks off a real scrape against the live sites, which can take a couple of minutes since a few of them go through a real browser. Refresh the dashboard afterward and you should see listings.

To have it run automatically in the background the way it will in production, start the job worker in a separate terminal:

```
bin/jobs
```

## Environment variables

Copy `.env.example` to `.env` and fill it in:

- **`DISCORD_WEBHOOK_URL`** — where the app posts new listings. Create one in Discord under a channel's settings, under Integrations → Webhooks, and paste the URL here. If you leave this blank, the app just writes what it would have posted to the Rails log instead of failing.

Nothing else is required to run the app locally. `.env` is listed in `.gitignore` so a real webhook URL never accidentally ends up in git history — only `.env.example`, which has no real values in it, gets committed.

## Running the tests

```
bin/rails test
```

There are tests for the scoring rules, the skip filters, the Craigslist scraper, the Listing and DailySummary models, and the dashboard controller.

## A few things that changed from the Python version

- **PDF tables**: the Python version used a library called pdfplumber, which reconstructs tables by looking at exact pixel positions on the page. Ruby doesn't have a direct equivalent, so `pdf_table_extractor.rb` does the same job by hand — grouping text by vertical position into rows, then splitting on wide horizontal gaps to find columns. It's not pixel-perfect on every PDF layout, but it's the same underlying technique.
- **Browser automation**: Playwright became Ferrum, which drives headless Chrome directly instead of through a separate browser-automation server. The production Docker image installs Chromium so this actually works when deployed.
- **Wiped-then-rebuilt table**: like the original, the listings table gets cleared at the start of every run and rebuilt from scratch, rather than being tracked as permanent history. Day-over-day trends live in the separate `daily_summaries` table instead, which is the Rails equivalent of the history.json file the Python version wrote for its GitHub Pages chart.

Everything else — which sites get scraped, what counts as a skip, how a listing earns points — is intentionally identical to the original.
