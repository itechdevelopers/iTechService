class AddCodeToLocations < ActiveRecord::Migration
  CODES = {
      'Бар' => 'bar',
      'Обновление контента' => 'content',
      'Готово' => 'done',
      'Архив' => 'archive',
      'Ремонт' => 'repair',
      'Гарантийники' => 'warranty'
  }
  class Location < ActiveRecord::Base
    attr_accessor :code
  end

  def change
    add_column :locations, :code, :string
    add_index :locations, :code

    Location.all.each do |location|
      location.update_column :code, CODES[location.name]
    end
  end
end
