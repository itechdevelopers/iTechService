# frozen_string_literal: true

class SeedManageOneCCheckoutsAbility < ActiveRecord::Migration[5.1]
  # Право на списки контроля по оплате через 1С: подтверждать ручные переносы
  # и закрывать разбор запчастей после возврата. Это надзор за закрытыми
  # деньгами, поэтому выдаёт только суперадмин.
  def up
    Ability.find_or_create_by!(name: 'manage_one_c_checkouts') do |ability|
      ability.admin_assignable = false
    end
  end

  def down
    Ability.find_by(name: 'manage_one_c_checkouts')&.destroy
  end
end
