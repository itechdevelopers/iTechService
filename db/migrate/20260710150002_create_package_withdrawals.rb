class CreatePackageWithdrawals < ActiveRecord::Migration[5.1]
  def change
    create_table :package_withdrawals do |t|
      t.references :package_stock, foreign_key: true, null: false
      t.references :user,          foreign_key: true, null: false  # водитель

      t.integer :boxes_count, null: false  # сколько коробок забрали
      t.date    :withdrawn_on, null: false # дата (водитель ставит вручную)
      t.string  :reason,       null: false # основание (куда берут пакеты)

      t.timestamps
    end
  end
end
