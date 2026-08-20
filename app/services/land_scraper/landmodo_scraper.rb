# Landmodo renders its search results with JavaScript, so this is one of the sites that
# genuinely needs a real browser (Ferrum here, Playwright in the Python original) instead
# of a plain HTTP request. Port of _landmodo() / LANDMODO_JS from scraper.py.
module LandScraper
  class LandmodoScraper < CardScraper
    SOURCE_NAME = "landmodo"
    URL = "https://www.landmodo.com/arizona-land-for-sale/cheap-land"

    # Runs inside the headless browser's JS engine, not in Ruby — it walks the rendered
    # DOM looking for listing cards and hands back plain {href, text} objects we can parse
    # in Ruby afterward. Copied selector-for-selector from the Python LANDMODO_JS constant.
    CARD_JS = <<~JS.freeze
      () => {
        const r = [];
        document.querySelectorAll('.search_result').forEach(el => {
          const text = (el.innerText || '').substring(0, 600);
          const link = el.querySelector('a[href*="/properties/"]');
          const href = link ? link.href : (el.querySelector('a') ? el.querySelector('a').href : '');
          if (text.length > 20) r.push({href, text});
        });
        return r;
      }
    JS
  end
end
