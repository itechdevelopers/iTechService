class CleanupExcessServiceJobSubscriptions < ActiveRecord::Migration[5.1]
  def up
    # Find users with more than 10 subscriptions
    users_with_excess = ActiveRecord::Base.connection.execute(<<-SQL)
      SELECT subscriber_id, COUNT(*) as subscription_count
      FROM service_job_subscriptions
      GROUP BY subscriber_id
      HAVING COUNT(*) > 10
    SQL

    users_with_excess.each do |row|
      user_id = row['subscriber_id']
      
      puts "Processing user #{user_id} with #{row['subscription_count']} subscriptions..."
      
      # Get all subscriptions for this user, ordered by service job creation date (newest first)
      # We'll keep the 10 newest and delete the rest
      subscriptions_to_delete = ActiveRecord::Base.connection.execute(<<-SQL)
        SELECT sjs.service_job_id
        FROM service_job_subscriptions sjs
        JOIN service_jobs sj ON sjs.service_job_id = sj.id
        WHERE sjs.subscriber_id = #{user_id}
        ORDER BY sj.created_at DESC
        OFFSET 10
      SQL
      
      service_job_ids = subscriptions_to_delete.map { |r| r['service_job_id'] }
      
      if service_job_ids.any?
        # Delete the excess subscriptions
        ActiveRecord::Base.connection.execute(<<-SQL)
          DELETE FROM service_job_subscriptions
          WHERE subscriber_id = #{user_id}
          AND service_job_id IN (#{service_job_ids.join(',')})
        SQL
        
        puts "  Deleted #{service_job_ids.length} oldest subscriptions for user #{user_id}"
      end
    end
    
    # Verify results
    remaining_excess = ActiveRecord::Base.connection.execute(<<-SQL)
      SELECT subscriber_id, COUNT(*) as subscription_count
      FROM service_job_subscriptions
      GROUP BY subscriber_id
      HAVING COUNT(*) > 10
    SQL
    
    if remaining_excess.count > 0
      puts "WARNING: #{remaining_excess.count} users still have more than 10 subscriptions"
    else
      puts "SUCCESS: All users now have 10 or fewer subscriptions"
    end
  end
  
  def down
    # This migration is not reversible as we're deleting data
    # and we don't have a way to know which subscriptions were deleted
    raise ActiveRecord::IrreversibleMigration
  end
end
