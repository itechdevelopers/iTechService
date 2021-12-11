class AddCityToDepartments < ActiveRecord::Migration
  class Department < ActiveRecord::Base; end

  def change
    add_reference :departments, :city, index: true, foreign_key: true

    reversible do |dir|
      dir.up do
        Department.find_each do |department|
          city = City.find_or_create_by(name: department.city)
          department.update_column(:city_id, city.id)
        end

        # change_column_null :departments, :city_id, false
        remove_column :departments, :city
      end
    end
  end
end
