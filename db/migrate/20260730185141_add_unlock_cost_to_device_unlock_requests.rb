class AddUnlockCostToDeviceUnlockRequests < ActiveRecord::Migration[5.1]
  def change
    # Себестоимость разблокировки в рублях (целое). Заполняет и видит только
    # суперадмин (гейт в policy). nil = не указана — тогда в строке не показываем.
    add_column :device_unlock_requests, :unlock_cost, :integer
  end
end
