class GeneralizeMaxPhoneLookups < ActiveRecord::Migration[5.1]
  def change
    rename_table :max_phone_lookups, :green_api_lookups
    rename_column :green_api_lookups, :max_name, :name
    # Значение по умолчанию — только чтобы заполнить прежние строки: все они
    # проверки MAX.
    add_column :green_api_lookups, :channel, :string, null: false, default: 'max_phone'
    change_column_default :green_api_lookups, :channel, from: 'max_phone', to: nil
    remove_index :green_api_lookups, column: :phone, unique: true
    add_index :green_api_lookups, %i[channel phone], unique: true
  end
end
