class CreateCheckListResponses < ActiveRecord::Migration[5.1]
  def change
    create_table :check_list_responses do |t|
      t.references :check_list, null: false, foreign_key: true
      t.references :checkable, polymorphic: true, null: false
      t.text :responses
      t.timestamps
    end

    add_index :check_list_responses, [:check_list_id, :checkable_type, :checkable_id],
              unique: true, name: 'unique_check_list_response'
  end
end
