namespace :mcp do
  desc 'Retry committed MCP notification outboxes (does not repeat business writes)'
  task dispatch_outbox: :environment do
    McpWrite.where(outcome: 'succeeded', dispatched_at: nil).where("outbox <> '[]'::jsonb").find_each(&:dispatch_outbox)
  end

  desc 'Revoke all MCP credentials for one AIS user'
  task revoke_user: :environment do
    id = Integer(ENV.fetch('AIS_MCP_REVOKE_USER_ID'))
    abort 'Positive user ID required' unless id.positive?
    McpCredential.where(user_id: id).update_all(revoked_at: Time.current)
    puts 'MCP credentials revoked'
  end
end
