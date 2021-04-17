class Entities::DepartmentEntity < Grape::Entity
  expose :id, :name, :short_name, :city_name, :brand_name
end
