# frozen_string_literal: true

# Столбцы расписания теперь идут по schedule_group_memberships.position, а до
# этого шли по дате создания сотрудника. Старые позиции перемешаны или равны 0,
# поэтому нумеруем их в каждом наборе по прежнему порядку — после выкатки
# таблица выглядит так же, как раньше.
class BackfillScheduleGroupMembershipPositions < ActiveRecord::Migration[5.1]
  def up
    execute <<~SQL
      UPDATE schedule_group_memberships m
      SET position = ranked.row_number - 1
      FROM (
        SELECT sgm.id,
               ROW_NUMBER() OVER (PARTITION BY sgm.schedule_group_id ORDER BY u.created_at, sgm.id) AS row_number
        FROM schedule_group_memberships sgm
        JOIN users u ON u.id = sgm.user_id
      ) ranked
      WHERE ranked.id = m.id
    SQL
  end

  # Прежний код позиции не читал — откатывать нечего.
  def down; end
end
