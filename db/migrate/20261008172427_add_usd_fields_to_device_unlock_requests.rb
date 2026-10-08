class AddUsdFieldsToDeviceUnlockRequests < ActiveRecord::Migration[5.1]
  def change
    # Цена разблокировки в долларах и курс, по которому её пересчитали в рубли.
    # Курс храним, чтобы себестоимость сходилась с ним и после смены курса.
    add_column :device_unlock_requests, :unlock_cost_usd, :decimal, precision: 10, scale: 2
    add_column :device_unlock_requests, :usd_rate, :decimal, precision: 10, scale: 4
  end
end
