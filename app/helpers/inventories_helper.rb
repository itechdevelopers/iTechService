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

  def inventory_lines_progress(inventory)
    t('inventories.index.progress_value',
      counted: inventory.counted_lines_count,
      total: inventory.lines.size)
  end
end
