require 'securerandom'
require 'stringio'
require 'shellwords'

namespace :production_safety do
  desc 'Lock production and pin an up-to-date, cumulative master revision'
  task :check do
    next unless fetch(:stage).to_s == 'production'
    requested = fetch(:branch).to_s
    raise 'Production accepts master or its full commit SHA only; merge the feature first.' unless requested == 'master' || requested.match?(/\A[0-9a-f]{40}\z/)
    local_head = nil
    run_locally do
      raise 'Commit or preserve local changes before deploying.' unless capture(:git, :status, '--porcelain').strip.empty?
      local_head = capture(:git, :'rev-parse', 'HEAD').strip
    end
    set :production_lock_owner, SecureRandom.hex(16)
    set :production_locked_hosts, []
    on roles(:app) do |host|
      lock = shared_path.join('production-deploy.lock')
      raise "Another deployment holds #{lock}; inspect it before retrying." unless test(:mkdir, lock)
      fetch(:production_locked_hosts) << host.to_s
      upload! StringIO.new(fetch(:production_lock_owner)), lock.join('owner')
      within repo_path do
        execute :git, :fetch, :origin, 'refs/heads/master:refs/heads/master'
        target = capture(:git, :'rev-parse', 'refs/heads/master').strip
        raise 'Requested revision is not the latest master.' unless requested == 'master' || requested == target
        raise 'Local deployment code is stale. Update this checkout to the latest master.' unless local_head == target
        current = capture(:cat, current_path.join('REVISION')).strip
        raise 'Master omits the running release. Merge production history first; do not overwrite it.' unless test(:git, :'merge-base', '--is-ancestor', current, target)
        set :production_previous_revision, current
        set :branch, target
      end
    end
  end

  desc 'Recheck master and running release immediately before publication'
  task :verify do
    next unless fetch(:stage).to_s == 'production'
    raise 'Production lock was not acquired.' if fetch(:production_locked_hosts, []).empty?
    on roles(:app) do
      within repo_path do
        remote = capture(:git, :'ls-remote', :origin, 'refs/heads/master').split.first
        raise 'Master advanced during deployment; retry with the new master.' unless remote == fetch(:branch)
      end
      current = capture(:cat, current_path.join('REVISION')).strip
      raise 'Production changed during deployment; refusing to overwrite it.' unless current == fetch(:production_previous_revision)
      raise 'Release revision does not match the approved master.' unless capture(:cat, release_path.join('REVISION')).strip == fetch(:branch)
      %w[app/controllers/weekly_markup_dashboards_controller.rb app/services/weekly_markup/dashboard_data.rb app/services/iphone_sales/dashboard.rb app/controllers/kpi_audit/episodes_controller.rb].each do |path|
        raise "Required production feature is missing: #{path}" unless test(:test, '-s', release_path.join(path))
      end
      %w[.env config/database.yml config/schedule.yml config/weekly_markup_import_token].each do |path|
        raise "Persistent configuration is not linked: #{path}" unless test(:test, '-L', release_path.join(path))
      end
    end
  end

  task :unlock do
    next unless fetch(:stage).to_s == 'production'
    on roles(:app) do |host|
      next unless fetch(:production_locked_hosts, []).include?(host.to_s)
      lock = shared_path.join('production-deploy.lock').to_s.shellescape
      owner = fetch(:production_lock_owner).to_s.shellescape
      execute "if [ \"$(cat #{lock}/owner 2>/dev/null)\" = #{owner} ]; then rm #{lock}/owner && rmdir #{lock}; fi"
    end
    set :production_locked_hosts, []
  end

  task :refuse_rollback do
    raise 'Production rollback requires an explicit recovery plan; publish a reviewed revert on master.' if fetch(:stage).to_s == 'production'
  end
end

before 'deploy:starting', 'production_safety:check'
before 'deploy:publishing', 'production_safety:verify'
after 'deploy:finished', 'production_safety:unlock'
after 'deploy:failed', 'production_safety:unlock'
before 'deploy:reverting', 'production_safety:refuse_rollback'
