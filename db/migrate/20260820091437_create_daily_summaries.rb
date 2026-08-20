# This migration builds "daily_summaries", the Rails equivalent of the history.json file
# the Python version wrote to docs/data/history.json after every run. Instead of a JSON
# file on disk, we get a real table we can query, but the fields are the same ones
# history.py computed: totals, price stats, and a per-source breakdown.
class CreateDailySummaries < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_summaries do |t|
      t.date :summary_date                        # the date this snapshot covers, one row per day the job runs
      t.integer :total                             # how many listings were in the table when the snapshot was taken
      t.integer :good                              # how many of those scored 50 or higher
      t.decimal :avg_price, precision: 12, scale: 2    # mean asking price across listings that had a real price
      t.decimal :median_price, precision: 12, scale: 2 # median asking price, less skewed by one huge outlier than the mean
      t.decimal :avg_score, precision: 5, scale: 1     # mean score, one decimal place same as the Python version rounded it
      t.text :by_source                            # JSON-encoded breakdown of {source => {count, avg_price}}, stored as text since SQLite has no native JSON column here

      t.timestamps                                 # created_at/updated_at bookkeeping columns
    end

    # A run only ever writes one summary per calendar day, so this keeps that guarantee at the database level too.
    add_index :daily_summaries, :summary_date, unique: true
  end
end
