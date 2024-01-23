class AddDismissalFieldsToUser < ActiveRecord::Migration[5.1]
  def change
    create_table :dismissal_reasons do |t|
      t.string :name
    end

    add_column :users, :dismissed_date, :datetime
    add_reference :users, :dismissal_reason, foreign_key: true
    add_column :users, :dismissal_comment, :text
  end
end