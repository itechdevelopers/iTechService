class CreateApprovalRequests < ActiveRecord::Migration[5.1]
  def change
    create_table :approval_requests do |t|
      t.bigint :service_job_id, null: false
      t.bigint :requester_id
      t.bigint :responder_id
      t.text :question, null: false
      t.string :status, null: false, default: 'pending'
      t.text :response_comment
      t.datetime :responded_at

      t.timestamps
    end

    add_index :approval_requests, :service_job_id
    add_index :approval_requests, :requester_id
    add_index :approval_requests, :responder_id
    add_index :approval_requests, :status

    # Один неотвеченный запрос на ремонт. Индекс, а не только валидация:
    # два технаря (или две вкладки) могут дойти до создания одновременно.
    add_index :approval_requests, :service_job_id,
              unique: true,
              where: "status = 'pending'",
              name: 'index_approval_requests_on_pending_service_job'
  end
end
