class SeedGluingPauseReason < ActiveRecord::Migration[5.1]
  GLUING = { code: 'gluing', name: 'На проклейке', position: 5 }.freeze

  def up
    RepairPauseReason.find_or_create_by!(code: GLUING[:code]) do |r|
      r.name     = GLUING[:name]
      r.position = GLUING[:position]
    end
  end

  def down
    RepairPauseReason.where(code: GLUING[:code]).delete_all
  end
end
