# config valid for current version and patch releases of Capistrano
lock "~> 3.12.1"

set :application, 'itechservice'
set :repo_url, 'git@github.com:vaallery/iTechService.git'
set :branch, 'master'

# Default deploy_to directory is /var/www/my_app_name
# set :deploy_to, "/var/www/my_app_name"

# Default value for :format is :airbrussh.
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
set :format_options,
    command_output: true,
    log_file: "log/capistrano.log",
    color: :auto,
    truncate: false

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
append :linked_files, 'config/database.yml', 'config/schedule.yml'

# Default value for linked_dirs is []
append :linked_dirs, 'log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'tmp/pdf', 'public/system', 'public/uploads'

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }
set :default_env, secret_key_base: 'dummy-key', devise_secret_key: 'dummy-key'

# Default value for local_user is ENV['USER']
# set :local_user, -> { `git config user.name`.chomp }

# Default value for keep_releases is 5
# set :keep_releases, 5

# Uncomment the following to require manually verifying the host key before first deploy.
# set :ssh_options, verify_host_key: :secure

set :pg_user, fetch(:user)

set :rbenv_type, :system
set :rbenv_ruby, '2.4.10'

set :conditionally_migrate, true
set :whenever_identifier, fetch(:application)

# TODO add sidekiq hooks
#