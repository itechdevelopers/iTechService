require 'securerandom'
require 'shellwords'
require 'socket'
require 'stringio'
require 'time'

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
    # Случайный хвост оставляет за снятием лока прежнюю гарантию (снимаю только
    # свой), а префикс отвечает на вопрос, ради которого в занятый лок лезут
    # руками: кто и с какой машины его держит.
    operator = [ENV['USER'] || ENV['LOGNAME'] || 'unknown', Socket.gethostname].join('@')
    set :production_lock_owner, "#{operator} #{Time.now.utc.iso8601} pid=#{Process.pid} #{SecureRandom.hex(8)}"
    set :production_locked_hosts, []
    on roles(:app) do |host|
      lock = shared_path.join('production-deploy.lock')
      raise "Another deployment holds #{lock}; run `cat #{lock}/owner` to see who." unless test(:mkdir, lock)
      fetch(:production_locked_hosts) << host.to_s
      upload! StringIO.new(fetch(:production_lock_owner)), lock.join('owner')
      within repo_path do
        execute :git, :fetch, :origin, 'refs/heads/master:refs/heads/master'
        target = capture(:git, :'rev-parse', 'refs/heads/master').strip
        raise 'Requested revision is not the latest master.' unless requested == 'master' || requested == target
        raise "Local deployment code is stale: HEAD #{local_head[0, 9]} is not master #{target[0, 9]}. " \
              'Run: git checkout master && git pull' unless local_head == target
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

  # Откат переставляет симлинк на прошлый релиз, но схему БД не отматывает:
  # старый код встречает уже мигрированную базу. Поэтому по умолчанию отказ,
  # а не запрет — в аварии рычаг должен оставаться доступным.
  task :refuse_rollback do
    next unless fetch(:stage).to_s == 'production'
    next if ENV['ALLOW_PRODUCTION_ROLLBACK'] == '1'
    raise 'Production rollback is disabled by default: an older release can be incompatible with the migrated ' \
          'schema. Prefer a reviewed revert on master. Re-run with ALLOW_PRODUCTION_ROLLBACK=1 after checking ' \
          'which migrations ran since the target release.'
  end
end

before 'deploy:starting', 'production_safety:check'
before 'deploy:publishing', 'production_safety:verify'
after 'deploy:finished', 'production_safety:unlock'
after 'deploy:failed', 'production_safety:unlock'
before 'deploy:reverting', 'production_safety:refuse_rollback'
