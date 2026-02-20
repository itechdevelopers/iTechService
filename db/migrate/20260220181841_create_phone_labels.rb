class CreatePhoneLabels < ActiveRecord::Migration[5.1]
  def change
    create_table :phone_labels do |t|
      t.string :phone_number, null: false
      t.string :label, null: false

      t.timestamps
    end

    add_index :phone_labels, :phone_number, unique: true
  end
end
