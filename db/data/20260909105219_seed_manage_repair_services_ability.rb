# frozen_string_literal: true

class SeedManageRepairServicesAbility < ActiveRecord::Migration[5.1]
  # Право «Управление видами ремонта». Справочник видов ремонта и дерево групп
  # ведёт не руководитель, а тот, кто знает номенклатуру работ, — роль manager
  # или admin ради этого выдавать нельзя, она открывает слишком много другого.
  # Цены остаются за manage_stocks: их правит другой человек.
  # admin_assignable оставляем false — право позволяет удалять справочник целиком,
  # поэтому раздаёт его суперадмин.
  def up
    Ability.find_or_create_by!(name: 'manage_repair_services') do |ability|
      ability.admin_assignable = false
    end
  end

  def down
    Ability.find_by(name: 'manage_repair_services')&.destroy
  end
end
