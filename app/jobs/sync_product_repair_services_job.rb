# frozen_string_literal: true

class SyncProductRepairServicesJob < ApplicationJob
  queue_as :default

  def perform(product_group_id)
    product_group = ProductGroup.find_by(id: product_group_id)
    return unless product_group&.repair_group_id.present?

    # Получаем все repair_services из repair_group и его потомков
    repair_service_ids = collect_repair_service_ids(product_group.repair_group)
    return if repair_service_ids.empty?

    # Получаем все продукты из product_group и его потомков
    product_ids = collect_product_ids(product_group)
    return if product_ids.empty?

    # Синхронизируем repair_services для каждого продукта
    sync_products(product_ids, repair_service_ids)
  end

  private

  def collect_repair_service_ids(repair_group)
    # Получаем все repair_services из текущей группы и всех вложенных групп
    repair_group.subtree.flat_map { |rg| rg.repair_services.pluck(:id) }.uniq
  end

  def collect_product_ids(product_group)
    # Получаем все продукты из текущей группы и всех вложенных групп
    ([product_group] + product_group.descendants).flat_map { |pg| pg.products.pluck(:id) }.uniq
  end

  def sync_products(product_ids, repair_service_ids)
    # Используем find_each для батчевой обработки больших объемов
    Product.where(id: product_ids).find_each do |product|
      # Получаем текущие связи
      existing_ids = product.repair_service_ids

      # Добавляем новые, сохраняя старые (дедупликация через uniq)
      new_ids = (existing_ids + repair_service_ids).uniq

      # Обновляем только если есть изменения
      product.repair_service_ids = new_ids if existing_ids.sort != new_ids.sort
    end
  end
end
