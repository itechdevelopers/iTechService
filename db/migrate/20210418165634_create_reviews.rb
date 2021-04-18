class CreateReviews < ActiveRecord::Migration
  def change
    create_table :reviews do |t|
      t.references :user, index: true, foreign_key: true
      t.references :service_job, index: true, foreign_key: true
      t.references :client, index: true, foreign_key: true
      t.string :phone
      t.integer :value
      t.text :content
      t.string :token
      t.datetime :sent_at
      t.datetime :reviewed_at

      t.timestamps null: false
    end
  end
end
