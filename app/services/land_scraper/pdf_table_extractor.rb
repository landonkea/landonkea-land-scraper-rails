# Ruby doesn't have a direct equivalent of Python's pdfplumber, which reconstructs tables
# by looking at exact pixel positions of text on the page. pdf-reader (the gem we do have)
# only hands back a flat stream of positioned text fragments, so this class does the same
# job pdfplumber's extract_tables() did by hand: group fragments into rows by shared
# vertical position, then split each row into columns wherever there's a big horizontal
# gap between one fragment and the next. It won't be pixel-perfect on every PDF, but it's
# the same technique pdfplumber itself uses under the hood.
module LandScraper
  class PdfTableExtractor
    # Fragments within this many PDF points of each other vertically count as "the same row".
    ROW_TOLERANCE = 3
    # A horizontal gap wider than this many points between fragments is treated as a
    # column boundary rather than just a space within one cell.
    COLUMN_GAP = 8

    # Takes raw PDF bytes (a String) and returns an Array of rows, where each row is an
    # Array of cell strings — flattened across every page, since none of our county
    # scrapers care which physical page a row came from.
    def self.extract_rows(pdf_bytes)
      reader = PDF::Reader.new(StringIO.new(pdf_bytes))
      reader.pages.flat_map { |page| rows_for(page) }
    end

    def self.rows_for(page)
      receiver = PDF::Reader::PageTextReceiver.new
      page.walk(receiver)
      runs = receiver.runs.reject { |r| r.text.strip.empty? }
      return [] if runs.empty?

      # Group into rows by rounding the y-coordinate, then sort rows top-to-bottom (PDF
      # y-coordinates count up from the bottom of the page, so we sort descending).
      rows_by_y = runs.group_by { |r| (r.y / ROW_TOLERANCE).round }
      rows_by_y.sort_by { |y, _| -y }.map { |_, fragments| build_cells(fragments) }
    end
    private_class_method :rows_for

    # Within one row, sort fragments left-to-right, then merge adjacent fragments into a
    # single cell unless the horizontal gap between them is wide enough to be a real column break.
    def self.build_cells(fragments)
      sorted = fragments.sort_by(&:x)
      cells = []
      current = +sorted.first.text
      previous_end = sorted.first.endx

      sorted[1..].each do |fragment|
        if fragment.x - previous_end > COLUMN_GAP
          cells << current.strip
          current = +fragment.text
        else
          current << fragment.text
        end
        previous_end = fragment.endx
      end
      cells << current.strip
      cells
    end
    private_class_method :build_cells
  end
end
