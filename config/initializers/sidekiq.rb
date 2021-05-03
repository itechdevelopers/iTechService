Sidekiq.configure_server do |config|
  config.redis = { url: ENV['SK_REDIS_URL'] }

  if Sidekiq.server? && File.exists?((schedule_file = Rails.root.join('config/schedule.yml')))
    Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file)
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['SK_REDIS_URL'] }
end