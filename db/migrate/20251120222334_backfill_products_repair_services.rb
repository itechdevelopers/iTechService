class BackfillProductsRepairServices < ActiveRecord::Migration[5.1]
  def up
    say_with_time "Backfilling repair_services for products based on product_group.repair_group" do
      # Находим все ProductGroups с установленным repair_group_id
      product_groups_with_repair_group = ProductGroup.where.not(repair_group_id: nil)

      say "Found #{product_groups_with_repair_group.count} ProductGroups with repair_group"

      product_groups_with_repair_group.find_each do |product_group|
        # Запускаем синхронизацию через тот же Job для консистентности
        SyncProductRepairServicesJob.perform_now(product_group.id)
      end
    end
  end

  def down
    # Не удаляем связи при откате, так как они могли быть добавлены вручную
    say "Not removing repair_service associations (they might have been added manually)"
  end
end
