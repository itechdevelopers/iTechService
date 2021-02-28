class AddAbilitiesToUser < ActiveRecord::Migration
  def change
    add_column :users, :activities_mask, :integer

    User.where(id: [1, 192, 124, 141, 35, 95, 120, 127, 153, 155, 166, 175, 178, 185, 193, 194, 197, 198, 200, 202])
        .update_all(activities_mask: 7)
  end
end
