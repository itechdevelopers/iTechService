class ChangePackageStockSizeToString < ActiveRecord::Migration[5.1]
  # Размер перестаёт быть enum (small/medium/large) и становится свободным текстом,
  # который суперадмин вводит сам. Бэкфиллим прежние enum-коды в русский текст.
  def up
    execute <<~SQL
      ALTER TABLE package_stocks
      ALTER COLUMN size TYPE varchar
      USING CASE size
              WHEN 0 THEN 'Маленький'
              WHEN 1 THEN 'Средний'
              WHEN 2 THEN 'Большой'
              ELSE size::text
            END
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE package_stocks
      ALTER COLUMN size TYPE integer
      USING CASE size
              WHEN 'Маленький' THEN 0
              WHEN 'Средний' THEN 1
              WHEN 'Большой' THEN 2
              ELSE 0
            END
    SQL
  end
end
