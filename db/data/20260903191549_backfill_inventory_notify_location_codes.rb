class BackfillInventoryNotifyLocationCodes < ActiveRecord::Migration[5.1]
  # Ревизии, отправленные до появления выбора локаций, звали локацию «Ремонт» —
  # это поведение было зашито в коде. Проставляем его явно: пустой список после
  # этой миграции означает «на филиале никого не зовём», и уведомления о
  # пересчёте по старым ревизиям иначе перестали бы доходить до технарей.
  def up
    Inventory.where(notify_location_codes: []).update_all(notify_location_codes: %w[repair])
  end

  def down
    Inventory.where(notify_location_codes: %w[repair]).update_all(notify_location_codes: [])
  end
end
