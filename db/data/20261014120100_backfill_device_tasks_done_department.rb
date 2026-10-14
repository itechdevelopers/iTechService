# Филиал выполнения для задач, закрытых до появления device_tasks.done_department_id.
#
# Локация в момент done_at берётся из истории перемещений работы: последнее
# перемещение не позже done_at. Если его нет (история начинается позже), —
# локация, откуда работу увезли первым перемещением после done_at, и только
# потом текущая. Дальше те же правила, что в DeviceTask#execution_department_id:
# трансфер не засчитывается, вместо него — филиал исполнителя, затем текущий
# филиал работы.
class BackfillDeviceTasksDoneDepartment < ActiveRecord::Migration[5.1]
  # Пачки коммитятся по отдельности: техник, закрывающий задачу во время
  # деплоя, ждёт одну пачку, а не весь проход по таблице.
  disable_ddl_transaction!

  BATCH_SIZE = 5_000

  def up
    say_with_time 'device_tasks.done_department_id' do
      max_id = connection.select_value('SELECT MAX(id) FROM device_tasks').to_i
      (0..max_id).step(BATCH_SIZE).sum { |from| connection.exec_update(batch_sql(from, from + BATCH_SIZE)) }
    end
  end

  # Значения, проставленные здесь, не отличить от записанных при закрытии задачи;
  # колонку целиком убирает откат схемной миграции.
  def down; end

  private

  def batch_sql(from, to)
    <<~SQL
      UPDATE device_tasks
      SET done_department_id = resolved.department_id
      FROM (
        SELECT dt.id,
               COALESCE(CASE WHEN dep.role <> 4 THEN dep.id END, performer_dep.id, job_dep.id) AS department_id
        FROM device_tasks dt
        JOIN service_jobs sj ON sj.id = dt.service_job_id
        LEFT JOIN users performers ON performers.id = dt.performer_id
        LEFT JOIN departments performer_dep ON performer_dep.id = performers.department_id
        LEFT JOIN departments job_dep ON job_dep.id = sj.department_id
        LEFT JOIN LATERAL (
          SELECT NULLIF(hr.new_value, '') AS location_id
          FROM history_records hr
          WHERE hr.object_id = sj.id AND hr.object_type = 'ServiceJob' AND hr.column_name = 'location_id'
            AND hr.created_at <= dt.done_at
          ORDER BY hr.created_at DESC, hr.id DESC
          LIMIT 1
        ) before_done ON TRUE
        LEFT JOIN LATERAL (
          SELECT NULLIF(hr.old_value, '') AS location_id
          FROM history_records hr
          WHERE hr.object_id = sj.id AND hr.object_type = 'ServiceJob' AND hr.column_name = 'location_id'
            AND hr.created_at > dt.done_at
          ORDER BY hr.created_at, hr.id
          LIMIT 1
        ) after_done ON TRUE
        LEFT JOIN locations loc
          ON loc.id::text = COALESCE(before_done.location_id, after_done.location_id, sj.location_id::text)
        LEFT JOIN departments dep ON dep.id = loc.department_id
        WHERE dt.done_at IS NOT NULL AND dt.done_department_id IS NULL
          AND dt.id >= #{from.to_i} AND dt.id < #{to.to_i}
      ) resolved
      WHERE device_tasks.id = resolved.id AND resolved.department_id IS NOT NULL
    SQL
  end
end
