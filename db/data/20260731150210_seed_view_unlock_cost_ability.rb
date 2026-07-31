# frozen_string_literal: true

class SeedViewUnlockCostAbility < ActiveRecord::Migration[5.1]
  # Право «Видеть себестоимость разблокировки». Редактирует себестоимость только
  # суперадмин (policy #update_cost?), а видеть значение может суперадмин ИЛИ
  # обладатель этого права (policy #see_cost?). Данные чувствительные, поэтому
  # admin_assignable оставляем false — выдавать право могут только суперадмины
  # (полный список Ability.all в форме пользователя), не обычные админы.
  def up
    Ability.find_or_create_by!(name: 'view_unlock_cost') do |ability|
      ability.admin_assignable = false
    end
  end

  def down
    Ability.find_by(name: 'view_unlock_cost')&.destroy
  end
end
