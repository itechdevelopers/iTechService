class Entities::RepairServiceEntity < Grape::Entity
  expose :id, :name, :client_info
  expose :price do |repair_service, options|
    repair_service.price(options[:store].department)
  end
  expose :status do |repair_service, options|
    status = repair_service.remnants_s(options[:store])
    I18n.t("spare_parts.remnants.#{status}") if status
  end
  expose :spare_parts do |repair_service, options|
    repair_service.spare_parts.map do |spare_part|
      {id: spare_part.id, name: spare_part.name, quantity: spare_part.quantity_in_store(options[:store])}
    end
  end
end