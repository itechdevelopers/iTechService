# frozen_string_literal: true

# Опция влияет только на ключ алфавитной сортировки: «Дисплей iPhone 15 Pro»
# встаёт на букву «Д». В самом списке название всегда остаётся полным — иначе
# ревизия по нескольким моделям превратилась бы в десяток строк «Дисплей».
class RenameHideModelInNameToIgnoreModelInSort < ActiveRecord::Migration[5.1]
  def change
    rename_column :inventories, :hide_model_in_name, :ignore_model_in_sort
  end
end
