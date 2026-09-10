class CreateWeeklyMarkupImports < ActiveRecord::Migration[5.1]
  def change
    create_table :weekly_markup_imports do |t|
      t.string :delivery_id, null: false
      t.date :period_from, null: false
      t.date :period_to, null: false
      t.datetime :calculated_at, null: false
      t.string :methodology_version, null: false
      t.string :status, null: false
      t.jsonb :payload, null: false, default: {}
      t.text :error_message
      t.timestamps
    end

    add_index :weekly_markup_imports, :delivery_id, unique: true
    add_index :weekly_markup_imports, %i[status period_from period_to], name: 'index_weekly_markup_imports_for_dashboard'
    add_index :weekly_markup_imports, :calculated_at
  end
end
