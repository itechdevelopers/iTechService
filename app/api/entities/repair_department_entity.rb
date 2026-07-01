class Entities::RepairDepartmentEntity < Grape::Entity
  expose :short_name
  expose :has_repair do |department, _options|
    department.participates_in_repair_services?
  end
end
