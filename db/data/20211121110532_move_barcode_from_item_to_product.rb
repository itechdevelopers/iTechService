class MoveBarcodeFromItemToProduct < ActiveRecord::Migration[4.2]
  # 2021-11 backfill barcode_num из items в products для категорий с feature_accounting=false.
  # На проде применена в 2021. Содержимое удалено: за 4.5 года данные обновлялись другими путями,
  # повторный запуск стёр бы актуальные значения. Файл оставлен для целостности data_schema.

  def up
  end

  def down
  end
end
