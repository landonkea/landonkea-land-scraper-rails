# Land Zero runs on WordPress + Elementor, which renders its listing grid with JS. Port
# of _landzero() / LANDZERO_JS from scraper.py.
module LandScraper
  class LandZeroScraper < CardScraper
    SOURCE_NAME = "landzero"
    URL = "https://landzero.com/cheap-land/arizona/"

    # Elementor/WordPress sites don't have one consistent card class, so this selector
    # covers the several patterns Land Zero's theme actually uses — identical to the
    # Python LANDZERO_JS constant.
    CARD_JS = <<~JS.freeze
      () => {
        const r = [];
        document.querySelectorAll('.elementor-post, .e-loop-item, [class*="product"], article').forEach(el => {
          const text = (el.innerText || '').substring(0, 600);
          const link = el.querySelector('a');
          const href = link ? link.href : '';
          if (text.length > 20 && text.includes('$')) r.push({href, text});
        });
        return r;
      }
    JS
  end
end
