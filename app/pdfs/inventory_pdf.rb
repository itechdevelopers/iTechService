# encoding: utf-8
# frozen_string_literal: true

# Печатный бланк ревизии: пронумерованный список позиций с пустой графой под
# фактическое количество. По этому листу технари и считают на складе.
class InventoryPdf < Prawn::Document
  require 'prawn/measurement_extensions'

  COLUMN_WIDTHS = [30, 400, 80].freeze

  def initialize(inventory, view)
    @inventory = inventory
    @view = view

    super page_size: 'A4', page_layout: :portrait, margin: [20.mm, 15.mm, 20.mm, 15.mm]

    # Кириллица встроенным шрифтом Prawn не рисуется — подключаем тот же
    # DroidSans, что и в остальных документах проекта.
    font_families.update 'DroidSans' => {
      normal: "#{Rails.root}/app/assets/fonts/droidsans-webfont.ttf",
      bold: "#{Rails.root}/app/assets/fonts/droidsans-bold-webfont.ttf"
    }
    font 'DroidSans'
    font_size 9

    draw_header
    draw_lines
  end

  private

  attr_reader :inventory, :view

  def draw_header
    font_size 14 do
      text view.t('inventories.pdf.title', number: inventory.number), style: :bold
    end
    move_down 4
    text view.t('inventories.pdf.store', store: inventory.store&.name)
    text view.t('inventories.pdf.date', date: I18n.l(inventory.created_at.to_date))
    text view.t('inventories.pdf.sort_mode', mode: view.t("inventories.sort_modes.#{inventory.sort_mode}"))
    move_down 10
  end

  def draw_lines
    rows = [header_row] + inventory.lines.map { |line| line_row(line) }

    table(rows, column_widths: COLUMN_WIDTHS, header: true) do
      row(0).font_style = :bold
      row(0).background_color = 'EEEEEE'
      cells.borders = %i[top bottom left right]
      cells.padding = [3, 4, 3, 4]
      column(0).align = :center
      column(2).align = :center
    end
  end

  def header_row
    [
      view.t('inventories.show.columns.position'),
      view.t('inventories.show.columns.name'),
      view.t('inventories.pdf.fact_column')
    ]
  end

  # Учётное количество на бланке не печатаем: с листом идут по складу те же, кто
  # считает, и напечатанный остаток они перепишут в графу «Факт» не считая.
  def line_row(line)
    [
      line.position.to_s,
      line.name.to_s,
      ''
    ]
  end
end
