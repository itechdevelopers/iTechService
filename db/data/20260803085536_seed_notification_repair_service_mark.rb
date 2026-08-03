# frozen_string_literal: true

class SeedNotificationRepairServiceMark < ActiveRecord::Migration[5.1]
  def up
    mark = RepairServiceMark.find_or_initialize_by(code: 'notification')
    mark.name = 'с уведомлением'
    mark.title = '1. Что такое с уведомлением?'
    mark.position ||= 1
    mark.save!
  end

  def down
    RepairServiceMark.where(code: 'notification').delete_all
  end
end
