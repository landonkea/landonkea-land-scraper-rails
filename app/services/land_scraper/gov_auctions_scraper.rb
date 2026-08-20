# GoV Auctions lists government real-estate auctions and, like Landmodo, needs a real
# browser to render. Port of _govauctions() / GOVAUCTIONS_JS from scraper.py.
module LandScraper
  class GovAuctionsScraper < CardScraper
    SOURCE_NAME = "govauctions"
    URL = "https://govauctions.app/auctions/real-estate/arizona"

    # GoV Auctions wraps each listing card in either an a.card-surface or an a.group link,
    # so the selector checks both — same as the Python GOVAUCTIONS_JS constant.
    CARD_JS = <<~JS.freeze
      () => {
        const r = [];
        document.querySelectorAll('a.card-surface, a.group').forEach(a => {
          const text = (a.innerText || '').substring(0, 600);
          const href = a.href || '';
          if (text.includes('$') && text.length > 20) r.push({href, text});
        });
        return r;
      }
    JS
  end
end
