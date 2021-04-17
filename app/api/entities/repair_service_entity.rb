class Entities::RepairServiceEntity < Grape::Entity
  expose :id, :name, :client_info
  expose :prices do |repair_service, options|
    Hash[options[:departments].map { |department| [department.short_name, repair_service.price(department)] }]
  end
  expose :status do |repair_service, options|
    status = repair_service.remnants_s(options[:store])
    I18n.t("spare_parts.remnants.#{status}") if status
  end
  expose :spare_parts do |repair_service, options|
    repair_service.spare_parts.map do |spare_part|
      quantity = Hash[
        options[:departments].map do |department|
          [department.short_name, spare_part.quantity_in_store(department.spare_parts_store)]
        end
      ]
      {id: spare_part.id, name: spare_part.name, quantity: quantity}
    end
  end
end