class RemoveSubscriptionsForDoneArchivedJobs < ActiveRecord::Migration[5.1]
  def up
    # Get IDs of done and archive locations
    done_location_ids = Location.done.pluck(:id)
    archive_location_ids = Location.archive.pluck(:id)
    all_location_ids = done_location_ids + archive_location_ids
    
    if all_location_ids.any?
      # Count subscriptions to be deleted for logging
      count_sql = <<-SQL
        SELECT COUNT(*) FROM service_job_subscriptions
        WHERE service_job_id IN (
          SELECT id FROM service_jobs 
          WHERE location_id IN (#{all_location_ids.join(',')})
        )
      SQL
      
      count_result = ActiveRecord::Base.connection.execute(count_sql)
      count = count_result.first['count'].to_i
      
      if count > 0
        # Delete subscriptions for jobs at done/archive locations
        delete_sql = <<-SQL
          DELETE FROM service_job_subscriptions
          WHERE service_job_id IN (
            SELECT id FROM service_jobs 
            WHERE location_id IN (#{all_location_ids.join(',')})
          )
        SQL
        
        ActiveRecord::Base.connection.execute(delete_sql)
        puts "Removed #{count} subscriptions for done/archived service jobs"
      else
        puts "No subscriptions found for done/archived service jobs"
      end
    else
      puts "No done or archive locations found"
    end
  end
  
  def down
    # Cannot restore deleted subscriptions
    raise ActiveRecord::IrreversibleMigration
  end
end
