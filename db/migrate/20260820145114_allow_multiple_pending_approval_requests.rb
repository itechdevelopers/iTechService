# По одной работе может висеть несколько неотвеченных согласований сразу
# (техник спрашивает клиента и про плату, и про экран). Снимаем partial unique
# index, который это запрещал.
class AllowMultiplePendingApprovalRequests < ActiveRecord::Migration[5.1]
  def up
    remove_index :approval_requests, name: 'index_approval_requests_on_pending_service_job'
  end

  def down
    add_index :approval_requests, :service_job_id,
              unique: true,
              where: "status = 'pending'",
              name: 'index_approval_requests_on_pending_service_job'
  end
end
