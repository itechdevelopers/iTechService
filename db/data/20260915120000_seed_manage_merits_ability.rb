# frozen_string_literal: true

class SeedManageMeritsAbility < ActiveRecord::Migration[5.1]
  # Право «Ставить плюсы сотрудникам». Раньше плюсы выставляли только старшие и
  # админы — право позволяет выдать эту возможность точечно, не меняя роль и не
  # делая сотрудника старшим. admin_assignable: false — выдаёт только суперадмин.
  def up
    Ability.find_or_create_by!(name: 'manage_merits') do |ability|
      ability.admin_assignable = false
    end
  end

  def down
    Ability.find_by(name: 'manage_merits')&.destroy
  end
end
