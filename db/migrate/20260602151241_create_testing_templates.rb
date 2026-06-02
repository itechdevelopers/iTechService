class CreateTestingTemplates < ActiveRecord::Migration[5.1]
  def change
    create_table :testing_templates do |t|
      t.text    :content, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
  end
end
