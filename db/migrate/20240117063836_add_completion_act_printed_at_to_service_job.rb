class AddCompletionActPrintedAtToServiceJob < ActiveRecord::Migration[5.1]
  def change
    add_column :service_jobs, :completion_act_printed_at, :datetime
  end
end
