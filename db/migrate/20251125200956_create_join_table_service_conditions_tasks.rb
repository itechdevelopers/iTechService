class CreateJoinTableServiceConditionsTasks < ActiveRecord::Migration[5.1]
  def change
    create_join_table :service_conditions, :tasks do |t|
      t.index [:service_condition_id, :task_id], name: 'idx_svc_cond_tasks_on_condition_and_task'
      t.index [:task_id, :service_condition_id], name: 'idx_svc_cond_tasks_on_task_and_condition'
    end
  end
end
