class CreatePlans < ActiveRecord::Migration[5.1]
  def change
    create_table :plans do |t|
      t.date    :month,   null: false
      t.integer :city_id, null: false
      t.string  :metric,  null: false
      t.integer :target,  null: false, default: 0
      t.timestamps
    end

    add_index :plans, %i[month city_id metric], unique: true
    add_foreign_key :plans, :cities
  end
end
