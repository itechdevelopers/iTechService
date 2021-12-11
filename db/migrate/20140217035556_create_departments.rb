class CreateDepartments < ActiveRecord::Migration
  class Department < ActiveRecord::Base
    attr_accessor :name, :role, :code, :url, :city, :address, :contact_phone, :schedule
  end

  def up
    create_table :departments do |t|
      t.string :name
      t.string :code
      t.integer :role
      t.string :url
      t.string :city
      t.string :address
      t.string :contact_phone
      t.text :schedule

      t.timestamps
    end
    add_index :departments, :role
    add_index :departments, :code
    Department.where(code: 'kh').first_or_create(name: 'Хабаровск', role: 1, address: '-', contact_phone: '-', schedule: '-', url: '-')
    Department.where(code: ENV['DEPARTMENT_CODE']).first_or_create(name: ENV['DEPARTMENT_NAME'], role: ENV['DEPARTMENT_ROLE'], address: '-', contact_phone: '-', schedule: '-', url: '-')
  end

  def down
    remove_index :departments, :role
    remove_index :departments, :code
    drop_table :departments
  end
end
