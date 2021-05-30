class AddStatusToReview < ActiveRecord::Migration
  def change
    add_column :reviews, :status, :string, default: :draft
  end
end
