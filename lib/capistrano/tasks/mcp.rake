# Opt-in deployment of the separate transport; existing release safety applies.
namespace :mcp do
  task :install do
    next unless ENV['AIS_MCP_DEPLOY'] == '1'
    on roles(:app) do
      within release_path.join('integrations/chatgpt-mcp') do
        execute :npm, :ci, '--omit=dev', '--ignore-scripts', '--no-audit', '--no-fund'
        execute :npm, :run, :check
      end
    end
  end
  task :restart do
    next unless ENV['AIS_MCP_DEPLOY'] == '1'
    on roles(:app) do
      execute :sudo, :systemctl, :restart, 'ais-mcp.service'
    end
  end
end

after 'deploy:updated', 'mcp:install'
after 'deploy:published', 'mcp:restart'
