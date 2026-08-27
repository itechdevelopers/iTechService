# frozen_string_literal: true

# Выгрузка ревизии в Excel — такой же бланк, как и PDF: список позиций с пустой
# графой под фактическое количество. Факт, автор и результат разбора намеренно
# не выгружаются: файл нужен для похода по складу, а не для отчёта.
class InventoryXlsx
  HEADERS = ['№', 'Номенклатура', 'По учёту', 'Факт'].freeze

  COLUMN_WIDTHS = [6, 55, 12, 12].freeze

  def initialize(inventory)
    @inventory = inventory
  end

  def to_xlsx(workbook)
    styles = build_styles(workbook)

    workbook.add_worksheet(name: "Ревизия №#{inventory.number}") do |sheet|
      sheet.add_row ["Ревизия №#{inventory.number} от #{I18n.l(inventory.created_at.to_date)}"],
                    style: styles[:title]
      sheet.add_row ["Склад: #{inventory.store&.name}"]
      sheet.add_row []

      sheet.add_row HEADERS, style: styles[:header]
      inventory.lines.each { |line| sheet.add_row(row_for(line), style: row_styles(styles)) }

      sheet.column_widths(*COLUMN_WIDTHS)
    end
  end

  private

  attr_reader :inventory

  # Графа «Факт» пустая — её заполняют руками на складе.
  def row_for(line)
    [line.position, line.name.to_s, line.expected_quantity, nil]
  end

  def row_styles(styles)
    [styles[:integer], styles[:text], styles[:integer], styles[:blank]]
  end

  def build_styles(workbook)
    sheet_styles = workbook.styles
    border = { style: :thin, color: '000000' }

    {
      title: sheet_styles.add_style(b: true, sz: 14),
      header: sheet_styles.add_style(b: true, bg_color: 'E6E6E6', border: border,
                                     alignment: { horizontal: :center, wrap_text: true }),
      text: sheet_styles.add_style(border: border),
      integer: sheet_styles.add_style(border: border, alignment: { horizontal: :center }, num_fmt: 1),
      blank: sheet_styles.add_style(border: border)
    }
  end
end
