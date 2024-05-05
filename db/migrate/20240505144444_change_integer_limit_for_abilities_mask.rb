class ChangeIntegerLimitForAbilitiesMask < ActiveRecord::Migration[5.1]
  def change
    change_column :users, :abilities_mask, :integer, limit: 8
  end
end
