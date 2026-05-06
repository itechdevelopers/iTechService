# frozen_string_literal: true

class SeedRepairStatuses < ActiveRecord::Migration[5.1]
  def up
    [
      { code: 'waiting',     name: 'В ожидании ремонта', color: '#5bc0de', position: 1 },
      { code: 'in_progress', name: 'В процессе ремонта', color: '#f0ad4e', position: 2 },
      { code: 'paused',      name: 'Пауза',              color: '#999999', position: 3 },
      { code: 'completed',   name: 'Ремонт завершён',    color: '#5cb85c', position: 4 }
    ].each do |attrs|
      RepairStatus.find_or_create_by!(code: attrs[:code]) do |s|
        s.name     = attrs[:name]
        s.color    = attrs[:color]
        s.position = attrs[:position]
        s.system   = true
      end
    end

    [
      ['Ждём запчасть',       1],
      ['Ждём согласования',   2],
      ['Нужен другой мастер', 3]
    ].each do |name, pos|
      RepairPauseReason.find_or_create_by!(name: name) { |r| r.position = pos }
    end
  end

  def down
    RepairStatus.where(code: %w[waiting in_progress paused completed]).delete_all
    RepairPauseReason.where(name: ['Ждём запчасть', 'Ждём согласования', 'Нужен другой мастер']).delete_all
  end
end
