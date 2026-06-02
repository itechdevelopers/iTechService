class SeedTestingPauseReason < ActiveRecord::Migration[5.1]
  TESTING = { code: 'testing', name: 'Тестирование', position: 6 }.freeze

  def up
    RepairPauseReason.find_or_create_by!(code: TESTING[:code]) do |r|
      r.name     = TESTING[:name]
      r.position = TESTING[:position]
    end
  end

  def down
    RepairPauseReason.where(code: TESTING[:code]).delete_all
  end
end
