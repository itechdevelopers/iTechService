# frozen_string_literal: true

class RemoveNewIntakeEnabledSetting < ActiveRecord::Migration[5.1]
  def up
    Setting.where(name: 'new_intake_enabled').destroy_all
  end

  # Флаг больше нигде не читается: восстановленные строки ничего бы не переключали.
  def down; end
end
