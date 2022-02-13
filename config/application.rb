require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

Dotenv::Railtie.load

module ItechService
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.1

    config.active_record.observers = :history_observer

    config.time_zone = 'Vladivostok'

    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}').to_s]
    config.i18n.default_locale = :ru

    config.generators do |g|
      g.jbuilder = false
      g.assets = false
      g.helper = false
      g.decorator = false
      g.template_engine :haml
      # g.template_engine :slim
      g.test_framework :rspec, fixture: false, fixture_replacement: :factory_bot
    end

    config.logger = ActiveSupport::Logger.new('/dev/null')

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.
  end
end
