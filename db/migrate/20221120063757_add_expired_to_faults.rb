class AddExpiredToFaults < ActiveRecord::Migration[5.1]
  class Fault < ApplicationRecord; end

  def change
    add_column :faults, :expired, :boolean, null: false, default: false

    reversible do |dir|
      dir.up { Fault.update_all(expired: false) }
    end
  end
end
