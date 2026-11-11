require "write_xlsx"
require "tempfile"
require "zip"

class BoqWorkbookBuilder
  COLUMNS = %w[A B C D E F G H].freeze

  COLUMN_WIDTHS = {
    "A" => 10.0,
    "B" => 7.44,
    "C" => 33.0,
    "D" => 5.44,
    "E" => 8.44,
    "F" => 15.33,
    "G" => 15.55,
    "H" => 16.11
  }.freeze

  HEADERS = {
    "A" => "Page",
    "B" => "Item",
    "C" => "Description",
    "D" => "Unit",
    "E" => "Bill Qty",
    "F" => "Claimed",
    "G" => "Rate",
    "H" => "Total"
  }.freeze

  GREY = "#D9D9D9"
  PURPLE = "#E4DFEC"
  ORANGE = "#FDE9D9"
  TAB_COLOR = :yellow

  DEFAULT_ROW_HEIGHT = 14.4
  DEFAULT_COL_WIDTH = "9.109375"
  LINE_HEIGHT = 13.2
  MIN_ROW_HEIGHT = 14.4
  MAX_DIGIT_WIDTH = 7
  FONT_SIZE_PT = 10
  PIXELS_PER_INCH = 96
  CELL_PADDING_PX = 5
  SPACE_ADVANCE = 278
  DEFAULT_ADVANCE_WIDTH = 556

  ARIAL_ADVANCE_WIDTHS = {
    " " => 278, "!" => 278, "\"" => 355, "#" => 556, "$" => 556, "%" => 889, "&" => 667,
    "'" => 191, "(" => 333, ")" => 333, "*" => 389, "+" => 584, "," => 278, "-" => 333,
    "." => 278, "/" => 278, "0" => 556, "1" => 556, "2" => 556, "3" => 556, "4" => 556,
    "5" => 556, "6" => 556, "7" => 556, "8" => 556, "9" => 556, ":" => 278, ";" => 278,
    "<" => 584, "=" => 584, ">" => 584, "?" => 556, "@" => 1015, "A" => 667, "B" => 667,
    "C" => 722, "D" => 722, "E" => 667, "F" => 611, "G" => 778, "H" => 722, "I" => 278,
    "J" => 500, "K" => 667, "L" => 556, "M" => 833, "N" => 722, "O" => 778, "P" => 667,
    "Q" => 778, "R" => 722, "S" => 667, "T" => 611, "U" => 722, "V" => 667, "W" => 944,
    "X" => 667, "Y" => 667, "Z" => 611, "[" => 278, "\\" => 278, "]" => 278, "^" => 469,
    "_" => 556, "`" => 333, "a" => 556, "b" => 556, "c" => 500, "d" => 556, "e" => 556,
    "f" => 278, "g" => 556, "h" => 556, "i" => 222, "j" => 222, "k" => 500, "l" => 222,
    "m" => 833, "n" => 556, "o" => 556, "p" => 556, "q" => 556, "r" => 333, "s" => 500,
    "t" => 278, "u" => 556, "v" => 500, "w" => 722, "x" => 500, "y" => 500, "z" => 500,
    "{" => 334, "|" => 260, "}" => 334, "~" => 584, "–" => 556, "—" => 1000,
    "’" => 191, "‘" => 191, "“" => 333, "”" => 333, "•" => 350
  }.freeze

  TEXT_FORMAT = "@"
  QTY_FORMAT = "0.00"
  RATE_FORMAT = '_-"R"* #,##0.00_-;\-"R"* #,##0.00_-;_-"R"* "-"??_-;_-@_-'
  TOTAL_FORMAT = "#,##0.00_);[Red](#,##0.00)"

  TITLE_ROW = 5
  RULE_ROW = 7
  HEADER_ROW = 8
  SPACER_ROW = 9
  BODY_START_ROW = 10
  FIRST_CONTENT_ROW = 11

  MARGIN_SIDE = 0.7
  MARGIN_TOP_BOTTOM = 0.75
  A4_PAPER = 9
  FREEZE_ROW = 8

  THIN = 1
  MEDIUM = 2
  DOUBLE = 6

  def initialize(sheet_name:, title:, rows:, claims:)
    @sheet_name = sheet_name.to_s
    @title = title.to_s
    @rows = rows.map { |row| normalize_row(row) }
    @claims = claims.map { |claim| normalize_claim(claim) }
  end

  def to_blob
    path = File.join(Dir.tmpdir, "boq-#{SecureRandom.hex(8)}.xlsx")
    begin
      build(path)
      patch_sheet_xml(path)
      File.binread(path)
    ensure
      begin
        File.delete(path) if File.exist?(path)
      rescue StandardError
        nil
      end
    end
  end

  def sheet_name
    sanitized = @sheet_name.upcase.gsub(/[\[\]:*?\/\\]/, " ").strip
    sanitized.empty? ? "BOQ" : sanitized[0, 31]
  end

  def title
    @title.upcase
  end

  def last_row
    total_row + 2 + ((@claims.length - 1) * 2)
  end

  def total_row
    FIRST_CONTENT_ROW + @rows.length + 1
  end

  def first_item_row
    index = @rows.index { |row| row[:kind] == :item }
    index ? FIRST_CONTENT_ROW + index : FIRST_CONTENT_ROW
  end

  def last_item_row
    index = @rows.rindex { |row| row[:kind] == :item }
    index ? FIRST_CONTENT_ROW + index : total_row
  end

  def total_value
    @rows.sum do |row|
      next 0 unless row[:kind] == :item

      (row[:claimed_qty].to_f * row[:rate].to_f).round(2)
    end
  end

  private

  def normalize_row(row)
    row = row.symbolize_keys if row.respond_to?(:symbolize_keys)
    kind = (row[:kind] || :item).to_sym
    {
      kind: kind,
      page: row[:page],
      item_code: row[:item_code],
      description: kind == :spacer ? "" : row[:description].to_s,
      unit: row[:unit],
      bill_qty: row[:bill_qty],
      claimed_qty: row[:claimed_qty],
      rate: row[:rate],
      total_formula: row.key?(:total_formula) ? row[:total_formula] : true
    }
  end

  def normalize_claim(claim)
    claim = claim.symbolize_keys if claim.respond_to?(:symbolize_keys)
    {
      label: claim[:label].to_s,
      amount: claim[:amount],
      balance: claim[:amount].nil?
    }
  end

  def build(path)
    @workbook = WriteXLSX.new(path)
    sheet = @workbook.add_worksheet(sheet_name)
    apply_page_setup(sheet)
    write_title_block(sheet)
    write_header_row(sheet)
    write_spacer_row(sheet)
    write_body(sheet)
    write_total_row(sheet)
    write_claims(sheet)
    @workbook.close
  end

  def apply_page_setup(sheet)
    sheet.set_default_row(DEFAULT_ROW_HEIGHT)
    sheet.tab_color = TAB_COLOR
    sheet.freeze_panes(FREEZE_ROW, 0)
    COLUMNS.each_with_index { |column, index| sheet.set_column(index, index, COLUMN_WIDTHS[column]) }
    sheet.print_area("A1:H#{last_row}")
    sheet.fit_to_pages(1, 0)
    sheet.margin_left = MARGIN_SIDE
    sheet.margin_right = MARGIN_SIDE
    sheet.margin_top = MARGIN_TOP_BOTTOM
    sheet.margin_bottom = MARGIN_TOP_BOTTOM
    sheet.paper = A4_PAPER
    sheet.set_portrait
    sheet.set_header("")
    sheet.set_footer("")
  end

  def write_title_block(sheet)
    sheet.write(TITLE_ROW - 1, 2, title, title_format)
    sheet.write_blank(TITLE_ROW - 1, 0, left_rule_format)
    sheet.write_blank(TITLE_ROW, 0, left_rule_format)
    sheet.write_blank(RULE_ROW - 1, 0, left_rule_bottom_format)
    (1..7).each { |column| sheet.write_blank(RULE_ROW - 1, column, bottom_rule_format) }
    sheet.set_row(RULE_ROW - 1, 15)
  end

  def write_header_row(sheet)
    COLUMNS.each_with_index do |column, index|
      sheet.write(HEADER_ROW - 1, index, HEADERS[column], header_format(column))
    end
    sheet.set_row(HEADER_ROW - 1, 15)
  end

  def write_spacer_row(sheet)
    spacer_formats.each_value.with_index do |format, index|
      sheet.write_blank(SPACER_ROW - 1, index, format)
    end
  end

  def write_body(sheet)
    sheet.write_blank(BODY_START_ROW - 1, 0, body_formats["A"])
    (1..7).each { |column| sheet.write_blank(BODY_START_ROW - 1, column, body_formats[COLUMNS[column]]) }

    @rows.each_with_index do |row, index|
      row_number = FIRST_CONTENT_ROW + index
      write_body_row(sheet, row_number, row)
    end
  end

  def write_body_row(sheet, row_number, row)
    formats = body_formats
    formats = formats.merge("C" => heading_format) if row[:kind] == :heading
    description = row[:kind] == :spacer ? nil : row[:description]

    sheet.write_blank(row_number - 1, 0, formats["A"])
    sheet.write_blank(row_number - 1, 1, formats["B"])
    write_cell(sheet, row_number, 2, description, formats["C"])
    write_cell(sheet, row_number, 3, row[:unit], formats["D"])
    write_cell(sheet, row_number, 4, row[:bill_qty], formats["E"])
    write_cell(sheet, row_number, 5, row[:claimed_qty], formats["F"])
    write_cell(sheet, row_number, 6, row[:rate], formats["G"])
    if row[:total_formula]
      write_total_formula(sheet, row_number, formats["H"], row)
    else
      sheet.write_blank(row_number - 1, 7, formats["H"])
    end
    sheet.set_row(row_number - 1, row_height(row))
  end

  def write_cell(sheet, row_number, column_index, value, format)
    if value.nil? || value.to_s.strip.empty?
      sheet.write_blank(row_number - 1, column_index, format)
    else
      sheet.write(row_number - 1, column_index, value, format)
    end
  end

  def write_total_formula(sheet, row_number, format, row)
    value = row[:kind] == :item ? (row[:claimed_qty].to_f * row[:rate].to_f).round(2) : 0.0
    sheet.write_formula(row_number - 1, 7, "=F#{row_number}*G#{row_number}", format, value)
  end

  def write_total_row(sheet)
    row_number = total_row
    formats = total_row_formats
    write_blank_body_row(sheet, row_number - 1)
    sheet.write_blank(row_number - 1, 0, formats["A"])
    sheet.write_blank(row_number - 1, 1, formats["B"])
    sheet.write(row_number - 1, 2, "TOTAL", formats["C"])
    sheet.write_blank(row_number - 1, 3, formats["D"])
    sheet.write_blank(row_number - 1, 4, formats["E"])
    sheet.write_blank(row_number - 1, 5, formats["F"])
    sheet.write_blank(row_number - 1, 6, formats["G"])
    sheet.write_formula(
      row_number - 1, 7,
      "=SUM(H#{first_item_row}:H#{last_item_row})",
      formats["H"],
      total_value.round(2)
    )
    sheet.set_row(row_number - 1, 15)

    write_blank_body_row(sheet, row_number + 1, 15)
  end

  def write_blank_body_row(sheet, row_number, height = MIN_ROW_HEIGHT)
    sheet.write_blank(row_number - 1, 0, body_formats["A"])
    (1..7).each { |column| sheet.write_blank(row_number - 1, column, body_formats[COLUMNS[column]]) }
    sheet.set_row(row_number - 1, height)
  end

  def write_claims(sheet)
    @claims.each_with_index do |claim, index|
      row_number = total_row + 2 + (index * 2)
      formats = body_formats
      formats = formats.merge("H" => last_claim_total_format) if claim[:balance]

      write_blank_body_row(sheet, row_number - 1) if index.positive?

      sheet.write_blank(row_number - 1, 0, formats["A"])
      sheet.write_blank(row_number - 1, 1, formats["B"])
      sheet.write(row_number - 1, 2, claim[:label], formats["C"])
      sheet.write_blank(row_number - 1, 3, formats["D"])
      sheet.write_blank(row_number - 1, 4, formats["E"])
      sheet.write_blank(row_number - 1, 5, formats["F"])
      sheet.write_blank(row_number - 1, 6, formats["G"])

      if claim[:balance]
        sheet.write_formula(row_number - 1, 7, balance_formula, formats["H"], balance_value)
      else
        sheet.write(row_number - 1, 7, claim[:amount].to_f, formats["H"])
      end
      sheet.set_row(row_number - 1, MIN_ROW_HEIGHT)
    end
  end

  def balance_formula
    claimed_cells = @claims.each_with_index
                              .reject { |claim, _| claim[:balance] }
                              .map { |_claim, index| "H#{total_row + 2 + (index * 2)}" }
    "=H#{total_row}#{claimed_cells.map { |cell| "-#{cell}" }.join}"
  end

  def balance_value
    claimed = @claims.reject { |claim| claim[:balance] || claim[:amount].nil? }.sum { |claim| claim[:amount].to_f }
    (total_value.round(2) - claimed).round(2)
  end

  def row_height(row)
    lines = wrapped_lines(row[:description])
    [ (LINE_HEIGHT * lines).round(2), MIN_ROW_HEIGHT ].max
  end

  def wrapped_lines(text)
    return 1 if text.strip.empty?

    text.split("\n", -1).sum { |segment| wrap_line(segment) }
  end

  def wrap_line(line)
    words = line.split(/\s+/).reject(&:empty?)
    return 1 if words.empty?

    lines = 1
    current = 0

    words.each do |word|
      width = text_width(word)

      if current.zero?
        used, current = split_word(width)
        lines += used
      elsif current + SPACE_ADVANCE + width <= available_width
        current += SPACE_ADVANCE + width
      else
        lines += 1
        used, current = split_word(width)
        lines += used
      end
    end

    lines
  end

  def split_word(width)
    used = (width.to_f / available_width).ceil - 1
    used = 0 if used.negative?
    [ used, width - (used * available_width) ]
  end

  def text_width(text)
    text.each_char.sum { |char| advance_width(char) }
  end

  def advance_width(char)
    ARIAL_ADVANCE_WIDTHS.fetch(char, DEFAULT_ADVANCE_WIDTH)
  end

  def available_width
    @available_width ||= begin
      pixels = (((256 * COLUMN_WIDTHS["C"]) + (128.0 / MAX_DIGIT_WIDTH).round) / 256.0) * MAX_DIGIT_WIDTH
      usable_pixels = pixels.round - CELL_PADDING_PX
      (usable_pixels / (FONT_SIZE_PT * PIXELS_PER_INCH / 72.0) * 1000).round
    end
  end

  def patch_sheet_xml(path)
    entries = []
    Zip::File.open(path) do |zip|
      zip.each do |entry|
        stream = entry.get_input_stream
        data = stream.read
        stream.close
        entries << [ entry.name, data ]
      end
    end

    sheet_entry = entries.find { |name, _data| name == "xl/worksheets/sheet1.xml" }
    raise "Boq worksheet XML missing from generated workbook" unless sheet_entry

    sheet_entry[1] = patch_sheet_content(sheet_entry[1])

    patched_path = "#{path}.patched"
    Zip::OutputStream.open(patched_path) do |zip|
      entries.each do |name, data|
        zip.put_next_entry(name)
        zip.write(data)
      end
    end

    File.delete(path)
    File.rename(patched_path, path)
  end

  def patch_sheet_content(xml)
    format_pr = %r{<sheetFormatPr([^>]*?)/>}
    raise "Boq worksheet XML has no sheetFormatPr element" unless xml.match?(format_pr)

    xml = xml.sub(format_pr) do
      attributes = Regexp.last_match(1).strip
      attributes = "#{attributes} " unless attributes.empty?
      %(<sheetFormatPr #{attributes}defaultColWidth="#{DEFAULT_COL_WIDTH}"/>)
    end

    cols = %r{<cols>.*?</cols>}m
    raise "Boq worksheet XML has no cols element" unless xml.match?(cols)

    xml.sub(cols) { "<cols>#{cols_xml}</cols>" }
  end

  def cols_xml
    COLUMNS.each_with_index.map do |column, index|
      width = COLUMN_WIDTHS[column].to_s.sub(/\.0\z/, "")
      %(<col min="#{index + 1}" max="#{index + 1}" width="#{width}" customWidth="1"/>)
    end.join
  end

  def title_format
    @title_format ||= workbook_format(
      font_name: "Calibri", size: 11, bold: true, align: "left", valign: "vcenter"
    )
  end

  def left_rule_format
    @left_rule_format ||= workbook_format(left: MEDIUM)
  end

  def left_rule_bottom_format
    @left_rule_bottom_format ||= workbook_format(left: MEDIUM, bottom: MEDIUM)
  end

  def bottom_rule_format
    @bottom_rule_format ||= workbook_format(bottom: MEDIUM)
  end

  def header_format(column)
    @header_formats ||= {}
    @header_formats[column] ||= begin
      properties = {
        font_name: "Calibri", size: 11, bold: true, underline: true,
        align: "center", valign: "vcenter", border: MEDIUM
      }
      properties[:bg_color] = GREY if %w[A B C D E G].include?(column)
      properties[:bg_color] = PURPLE if column == "F"
      properties[:bg_color] = ORANGE if column == "H"
      properties[:right] = THIN if column == "H"
      workbook_format(properties)
    end
  end

  def spacer_formats
    @spacer_formats ||= {
      "A" => workbook_format(font_name: "Calibri", size: 11, bg_color: GREY, left: MEDIUM, right: MEDIUM, top: MEDIUM),
      "B" => workbook_format(font_name: "Calibri", size: 11, bg_color: GREY, left: MEDIUM, right: MEDIUM, top: MEDIUM),
      "C" => workbook_format(font_name: "Calibri", size: 11, left: MEDIUM, right: MEDIUM, top: MEDIUM),
      "D" => workbook_format(font_name: "Calibri", size: 11, left: MEDIUM, top: MEDIUM),
      "E" => workbook_format(font_name: "Calibri", size: 11, left: THIN, right: THIN, top: THIN),
      "F" => workbook_format(font_name: "Calibri", size: 11, bg_color: PURPLE, left: THIN, right: THIN, top: THIN),
      "G" => workbook_format(font_name: "Calibri", size: 11, right: THIN, top: THIN),
      "H" => workbook_format(font_name: "Calibri", size: 11, bg_color: ORANGE, right: THIN, top: MEDIUM)
    }
  end

  def body_formats
    @body_formats ||= {
      "A" => workbook_format(body_format_properties("A")),
      "B" => workbook_format(body_format_properties("B")),
      "C" => workbook_format(body_format_properties("C")),
      "D" => workbook_format(body_format_properties("D")),
      "E" => workbook_format(body_format_properties("E")),
      "F" => workbook_format(body_format_properties("F")),
      "G" => workbook_format(body_format_properties("G")),
      "H" => workbook_format(body_format_properties("H"))
    }
  end

  def heading_format
    @heading_format ||= workbook_format(
      font_name: "Arial", size: 10, color: "#000000", bold: true,
      valign: "top", text_wrap: true, left: MEDIUM, right: MEDIUM
    )
  end

  def total_row_formats
    @total_row_formats ||= {
      "A" => bold_body_format("A"),
      "B" => bold_body_format("B"),
      "C" => bold_body_format("C"),
      "D" => bold_body_format("D"),
      "E" => bold_body_format("E"),
      "F" => bold_body_format("F"),
      "G" => bold_body_format("G"),
      "H" => workbook_format(
        font_name: "Calibri", size: 11, color: "#000000", bold: true,
        num_format: TOTAL_FORMAT, valign: "vcenter", bg_color: ORANGE,
        left: THIN, right: THIN, bottom: DOUBLE
      )
    }
  end

  def bold_body_format(column)
    workbook_format(body_format_properties(column).merge(bold: true))
  end

  def last_claim_total_format
    @last_claim_total_format ||= workbook_format(
      font_name: "Calibri", size: 11, color: "#000000", num_format: TOTAL_FORMAT,
      valign: "vcenter", bg_color: ORANGE, left: THIN, right: THIN
    )
  end

  def body_format_properties(column)
    case column
    when "A"
      { font_name: "Arial", size: 10, color: "#000000", num_format: TEXT_FORMAT, valign: "top", left: MEDIUM, right: MEDIUM }
    when "B"
      { font_name: "Arial", size: 10, color: "#000000", num_format: TEXT_FORMAT, valign: "top", left: MEDIUM, right: MEDIUM }
    when "C"
      { font_name: "Arial", size: 10, color: "#000000", valign: "top", text_wrap: true, left: MEDIUM, right: MEDIUM }
    when "D"
      { font_name: "Arial", size: 10, color: "#000000", align: "center", left: MEDIUM }
    when "E"
      { font_name: "Arial", size: 10, color: "#000000", num_format: QTY_FORMAT, align: "right", left: THIN, right: THIN }
    when "F"
      { font_name: "Arial", size: 10, color: "#000000", num_format: "General", align: "right", left: THIN, right: THIN }
    when "G"
      { font_name: "Arial", size: 10, color: "#000000", num_format: RATE_FORMAT, right: THIN }
    else
      { font_name: "Calibri", size: 11, color: "#000000", num_format: TOTAL_FORMAT, valign: "vcenter", bg_color: ORANGE, right: THIN }
    end
  end

  def workbook_format(properties)
    properties = properties.dup
    font_name = properties.delete(:font_name)
    format = @workbook.add_format(properties)
    format.font_style.name = font_name if font_name
    format
  end
end
