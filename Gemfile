source 'https://rubygems.org'

ruby '2.4.10'

gem 'rails', '4.2.11.1'
gem 'protected_attributes', '~> 1.1.4'
gem 'rails-observers', '~> 0.1.5'
gem 'pg', '~> 0.21.0'
gem 'rails-pg-extras'
gem 'httparty', '~> 0.16.3'
# gem 'haml-rails', '~> 0.3.5'
gem 'hamlit', '~> 2.2.0'
# gem 'hamlit-rails', '~> 0.1.0'
# gem 'slim-rails'
gem 'jquery-rails', '~> 4.1.1'
gem 'jquery-ui-rails', '~> 5.0.5'
gem 'simple_form', '~> 3.5.1'
gem 'jbuilder', '~> 2.0'
gem 'devise', '~> 4.0.3'
gem 'devise_token_auth', '~> 0.1.37'

gem 'active_interaction', '~> 3.6'
gem 'dry-validation', '~> 0.12.0'
gem 'dry-transaction', '~> 0.13.0'
gem 'trailblazer', '~> 2.0.7'
gem 'trailblazer-rails', '~> 1.0.4'

gem 'trailblazer-cells', '~> 0.0.3'
gem 'cells-rails', '~> 0.0.7'
gem 'cells-slim', '~> 0.0.5'
gem 'reform-rails', '~> 0.1'

gem 'pundit', '~> 2.1.0'
gem 'kaminari', '~> 1.0.0'
gem 'kaminari-cells', '~> 1.0.0'
gem 'ancestry', '~> 2.1.0'
gem 'prawn', '~> 2.1.0'
gem 'prawn-table', '~> 0.2.1'
gem 'carrierwave', '~> 1.3.2'#, '~> 0.8.0'
gem 'mini_magick', '~> 4.9.4'
gem 'ckeditor', '~> 4.1.6'
gem 'uuidtools', '~> 2.1.5'
gem 'interactor-rails', '~> 2.0.2'
gem 'exception_notification', '~> 4.1.4'#, git: 'git://github.com/alanjds/exception_notification.git'
gem 'private_pub', '~> 1.0.3'
gem 'thin', '~> 1.6.4'
gem 'twitter-bootstrap-rails', '~> 2.2.7'#, :git => 'git://github.com/seyhunak/twitter-bootstrap-rails.git'
gem 'irwi', '~> 0.5.0'
gem 'RedCloth', '~> 4.3.1'
gem 'roo', '~> 2.4.0'
gem 'roo-xls', '~> 1.2'
gem 'paperclip', '~> 4.3.6'
gem 'barby', '~> 0.6.4'
gem 'acts_as_list', '~> 0.7.4'
gem 'sidekiq', '~> 5.2.6'
# gem 'sidekiq-statistic'
gem 'sinatra', '~> 1.0', require: false
gem 'sidekiq-cron', '~> 1.1'
gem 'whenever', '>= 0.8.4', require: false
gem 'grape', '~> 0.6.1'
gem 'grape-entity', '~> 0.4.1'
gem 'rmagick', '~> 2.15.4'
gem 'zeroclipboard-rails'
gem 'sqlite3', '~> 1.3.13'
gem 'vpim', '~> 13.11.11'
gem 'draper', '~> 2.1.0'
gem 'seedbank', '~> 0.4.0'
gem 'daemons', '~> 1.3.1'
gem 'dotenv-rails', '~> 2.2.1'
gem 'tzinfo-data'

gem 'coffee-rails', '~> 4.1.0'
# See https://github.com/rails/execjs#readme for more supported runtimes
gem 'therubyracer', '~> 0.12.3', :platforms => :ruby
gem 'sass-rails', '~> 5.0.6'
gem 'less-rails', '~> 2.7.1'
gem 'rails-ujs', '~> 0.1.0'
gem 'uglifier', '>= 1.3.0'
gem 'bootstrap-colorpicker-rails', '~> 0.3.1', :require => 'bootstrap-colorpicker-rails'
#, :git => 'git://github.com/alessani/bootstrap-colorpicker-rails.git'
# gem 'turbo-sprockets-rails3', '~> 0.3.14'

# gem 'nokogiri', github: 'sparklemotion/nokogiri'
gem 'nokogiri', '~> 1.10.10'
gem 'ru_propisju', '~> 2.5.0'

group :development do
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  # gem 'spring'

  # Access an IRB console on exception pages or by using <%= console %> in views
  gem 'web-console', '~> 2.0'

  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug'
  gem 'quiet_assets', '~> 1.1.0'
  gem 'binding_of_caller', '~> 0.7.2'
  gem 'meta_request', '~> 0.2.8'
  gem 'letter_opener', '~> 1.4.1'
  gem 'rails-erd', '~> 1.5.2'
end

group :test do
  # gem 'rspec-rails', '~> 3.8.0'
  gem 'capybara', '~> 2.15.4'
  gem 'capybara-selenium', '~> 0.0.6'
  gem 'chromedriver-helper', '~> 1.1.0'
  gem 'poltergeist', '~> 1.16.0'
  gem 'database_cleaner', '~> 1.6.1'
  gem 'factory_girl_rails', '~> 4.8.0'
  gem 'faker', '~> 1.8.4'
  gem 'simplecov', '~> 0.12.0', :require => false

  gem 'shoulda', '~> 3.5.0'
  # gem 'shoulda-matchers', '~> 2.8.0'
  gem 'mocha', '~> 1.1.0'
end

group :development, :test do
  gem "rspec-rails"
  gem "rubocop"
  gem "rubocop-faker"
  gem "rubocop-rails"
  gem "rubocop-rspec"
  gem "shoulda-matchers"
  gem "standard"
end

# group :production do
#   # gem 'unicorn', '~> 4.6.2'
#   # gem 'puma'
#   gem 'passenger', '>= 5.0.25', require: 'phusion_passenger/rack_handler'
# end

group :deploy, :development do
  gem 'capistrano', '~> 3.12.1', require: false
  gem 'capistrano-rails', '~> 1.4.0', require: false
  # gem 'capistrano-rvm', '~> 0.1.2'
  gem 'capistrano-rbenv', '~> 2.1.6'
  gem 'capistrano-bundler', '~> 1.6.0'
  gem 'capistrano-passenger', '~> 0.2.0'
  gem 'capistrano-rails-collection', '~> 0.1.0'
  gem 'capistrano-faster-assets', '~> 1.1.0'
  gem 'capistrano-ssh-doctor', '~> 1.0.0'
  gem 'capistrano-db-tasks', '~> 0.6', require: false
  gem 'capistrano-sidekiq', '~> 1.0.3'
  gem 'ed25519', '>= 1.2', '< 2.0'
  gem 'bcrypt_pbkdf', '>= 1.0', '< 2.0'
end
