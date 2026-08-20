# Computes today's stats across every listing currently in the table and saves them as a
# DailySummary row. This is the Rails equivalent of save_daily_summary() in the Python
# history.py — same numbers (total, good count, average/median price, average score, a
# per-source breakdown), just written to a database row instead of appended to a JSON file.
module LandScraper
  class HistorySnapshot
    # Returns the saved DailySummary, or nil if there were no listings to summarize —
    # matches the Python version returning None on an empty table.
    def self.save
      listings = Listing.all.to_a
      return nil if listings.empty?

      prices = listings.filter_map { |l| l.price if l.price.to_f > 0 }
      scores = listings.map { |l| l.score.to_i }

      by_source = listings.group_by(&:source).transform_values do |group|
        group_prices = group.filter_map { |l| l.price if l.price.to_f > 0 }
        {
          "count" => group.size,
          "avg_price" => group_prices.any? ? (group_prices.sum / group_prices.size).round : 0
        }
      end

      summary = DailySummary.find_or_initialize_by(summary_date: Date.current)
      summary.assign_attributes(
        total: listings.size,
        good: listings.count(&:good?),
        avg_price: prices.any? ? (prices.sum / prices.size).round : 0,
        median_price: prices.any? ? median(prices) : 0,
        avg_score: scores.any? ? (scores.sum.to_f / scores.size).round(1) : 0,
        by_source: by_source
      )
      summary.save!
      summary
    end

    # Ruby's stdlib doesn't ship a median function the way Python's `statistics` module
    # does, so this sorts the list and picks the middle (averaging the two middle values
    # for an even-sized list) by hand.
    def self.median(values)
      sorted = values.sort
      mid = sorted.length / 2
      if sorted.length.odd?
        sorted[mid].round
      else
        ((sorted[mid - 1] + sorted[mid]) / 2.0).round
      end
    end
    private_class_method :median
  end
end
