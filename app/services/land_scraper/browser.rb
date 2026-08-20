# Thin wrapper around Ferrum (a real headless Chrome, driven the same way Playwright drove
# one in the Python version). One Browser instance is shared across every JS-rendered site
# in a single scrape run so we only pay the cost of starting Chrome once, same idea as the
# Python code sharing one Playwright `browser` object across _landmodo/_govauctions/etc.
module LandScraper
  class Browser
    def initialize
      # `no-sandbox` is needed because the production Docker container runs Chrome inside
      # another container without the kernel privileges Chrome's own sandbox wants — a
      # common requirement for headless Chrome in any containerized environment.
      @ferrum = Ferrum::Browser.new(headless: true, timeout: 20, process_timeout: 20, browser_options: { "no-sandbox": nil })
    end

    # Loads a URL in a fresh page, scrolls it a few times to trigger lazy-loaded content
    # (the same trick the Python version used via page.evaluate('window.scrollBy...')),
    # then runs the caller's JS snippet and returns whatever array it produces.
    # scroll_times/scroll_pixels default to the values _pw_scrape() used for most sites;
    # the Maricopa scraper passes its own (5 scrolls of 800px) to match _maricopa().
    def scrape(url, js, scroll_times: 3, scroll_pixels: 1000)
      page = @ferrum.create_page
      # A fresh navigator.webdriver override on every page — the closest cheap equivalent
      # to playwright_stealth's bot-detection patching, without pulling in a whole gem for it.
      page.evaluate("Object.defineProperty(navigator, 'webdriver', { get: () => undefined })")
      page.go_to(url)
      sleep(2) # give the page's own JavaScript a moment to render before we start scrolling
      scroll_times.times do
        page.execute("window.scrollBy(0, #{scroll_pixels})")
        sleep(0.5)
      end
      page.evaluate(js)
    rescue Ferrum::Error, Ferrum::TimeoutError
      # A slow or blocked page just means "no listings from this source today" —
      # matches the bare `except:` around every Playwright scraper in the Python version.
      []
    ensure
      page&.close
    end

    # Grabs the full visible text of a page's <body> after scrolling — used by the
    # Maricopa scraper, which parses plain text instead of pulling discrete DOM nodes.
    def page_text(url, scroll_times: 5, scroll_pixels: 800)
      page = @ferrum.create_page
      page.evaluate("Object.defineProperty(navigator, 'webdriver', { get: () => undefined })")
      page.go_to(url)
      sleep(2)
      scroll_times.times do
        page.execute("window.scrollBy(0, #{scroll_pixels})")
        sleep(0.3)
      end
      page.evaluate("document.body.innerText")
    rescue Ferrum::Error, Ferrum::TimeoutError
      nil
    ensure
      page&.close
    end

    # Shuts down the underlying Chrome process — must be called once the run is done,
    # or a headless Chrome process leaks past the job's lifetime.
    def quit
      @ferrum.quit
    end
  end
end
