# frozen_string_literal: true

# Проклейка хранила срок числом часов; теперь срок любой паузы — момент
# окончания в pause_until. Переводим старые записи, чтобы бейдж и напоминания
# читали одно поле.
class BackfillPauseUntilFromGluingHours < ActiveRecord::Migration[5.1]
  def up
    say_with_time 'repair_status_changes.pause_until from gluing_hours' do
      connection.exec_update(<<~SQL)
        UPDATE repair_status_changes
        SET pause_until = changed_at + gluing_hours * INTERVAL '1 hour'
        WHERE gluing_hours IS NOT NULL AND pause_until IS NULL
      SQL
    end
  end

  # После переноса новые проклейки пишут только pause_until, поэтому
  # откатываем лишь записи, у которых остались часы.
  def down
    connection.exec_update(<<~SQL)
      UPDATE repair_status_changes
      SET pause_until = NULL
      WHERE gluing_hours IS NOT NULL
    SQL
  end
end
