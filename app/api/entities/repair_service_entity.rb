class Entities::RepairServiceEntity < Grape::Entity
  expose :id, :name, :client_info
  expose :prices do |repair_service, options|
    Hash[options[:departments].map { |department| [department.short_name, repair_service.price(department)] }]
  end
  expose :status do |repair_service, options|
    get_cached_status(repair_service, options[:store])
  end
  expose :spare_parts do |repair_service, options|
    get_cached_spare_parts(repair_service, options[:departments])
  end

  private

  def get_cached_spare_parts(repair_service, departments)
    cache_key = ['repair_service/spare_parts', repair_service.updated_at.to_s(:db), repair_service.id].join('-')
    Rails.cache.fetch(cache_key, expires_in: 1.day) do
      repair_service.spare_parts.map do |spare_part|
        quantity = Hash[
          departments.map do |department|
            [department.short_name, spare_part.quantity_in_store(department.spare_parts_store)]
          end
        ]
        { id: spare_part.id, name: spare_part.name, quantity: quantity }
      end
    end
  end

  def get_cached_status(repair_service, store)
    cache_key = ['repair_service/sp_remnants/status', repair_service.updated_at.to_s(:db), repair_service.id].join('-')
    Rails.cache.fetch(cache_key, expires_in: 1.day) do
      status = repair_service.remnants_s(store)
      I18n.t("spare_parts.remnants.#{status}") if status
    end
  end
end
