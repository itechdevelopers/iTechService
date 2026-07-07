class CreateOrderFeedbacks < ActiveRecord::Migration[5.1]
  def change
    create_table :order_feedbacks do |t|
      t.references :order, type: :integer, foreign_key: true, null: false

      t.datetime :scheduled_on
      t.text     :details
      t.text     :log
      t.integer  :postpone_count, null: false, default: 0

      t.timestamps
    end

    add_index :order_feedbacks, :scheduled_on
  end
end
