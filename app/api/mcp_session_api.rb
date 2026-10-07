# frozen_string_literal: true

class McpSessionApi < Grape::API
  version 'v1', using: :path
  format :json

  post 'mcp_sessions' do
    username = params[:username].to_s.downcase
    user = User.find_first_by_auth_conditions(auth_token: username)
    error!({ error: 'Invalid username or password.' }, 401) unless user && !user.is_fired? && user.valid_password?(params[:password].to_s)
    { token: McpApiToken.issue(user), expires_in: 3600 }
  end

  get 'mcp_sessions/current' do
    token = auth_token_from_headers
    error!({ error: 'Unauthorized' }, 401) unless token.to_s.start_with?('mcp_') && McpApiToken.authenticate(token)
    { active: true }
  end

  delete 'mcp_sessions/current' do
    token = auth_token_from_headers
    error!({ error: 'Unauthorized' }, 401) unless token.to_s.start_with?('mcp_') && McpApiToken.authenticate(token)
    McpApiToken.revoke(token)
    { success: true }
  end
end
