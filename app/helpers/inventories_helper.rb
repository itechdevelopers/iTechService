# frozen_string_literal: true

module InventoriesHelper
  # Сколько цветов в палитре подсветки авторов (см. inventories.css.scss).
  AUTHOR_COLORS_COUNT = 8

  # Цвет закрепляется за человеком по его id, а не по порядку появления в
  # ревизии: иначе после перезагрузки страницы или в соседней ревизии тот же
  # технарь оказался бы другого цвета, и подсветка перестала бы что-то значить.
  def inventory_author_color_index(user)
    return 0 if user.blank?

    user.id % AUTHOR_COLORS_COUNT
  end

  # У товароведа после сдачи расхождение важнее авторства: он ищет, где факт
  # разошёлся с учётом, а не кто вписал число. Поэтому красная подсветка
  # перебивает цвет автора.
  def inventory_line_row_class(line, reviewing:)
    return 'inventories__line--discrepancy' if reviewing && line.discrepancy?
    return nil unless line.counted? && line.counted_by

    "inventories__line--author-#{inventory_author_color_index(line.counted_by)}"
  end

  def inventory_lines_progress(inventory)
    t('inventories.index.progress_value',
      counted: inventory.counted_lines_count,
      total: inventory.lines.size)
  end
end
