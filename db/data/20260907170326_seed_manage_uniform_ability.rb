# frozen_string_literal: true

class SeedManageUniformAbility < ActiveRecord::Migration[5.1]
  # Право «Учёт рабочей формы». Раздел, движения по складу и блок «Выдано» в
  # чужих профилях открыты суперадминам ИЛИ обладателям этого права: учёт формы
  # ведёт кладовщик, а роль суперадмина ради этого выдавать нельзя.
  # admin_assignable оставляем false — выдаёт право суперадмин.
  def up
    Ability.find_or_create_by!(name: 'manage_uniform') do |ability|
      ability.admin_assignable = false
    end
  end

  def down
    Ability.find_by(name: 'manage_uniform')&.destroy
  end
end
