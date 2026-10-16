# frozen_string_literal: true

class SeedReceiveRepairCatalogBypassNotificationsAbility < ActiveRecord::Migration[5.1]
  def up
    Ability.find_or_create_by!(name: 'receive_repair_catalog_bypass_notifications') do |ability|
      ability.admin_assignable = false
    end
  end

  def down
    Ability.find_by(name: 'receive_repair_catalog_bypass_notifications')&.destroy
  end
end
