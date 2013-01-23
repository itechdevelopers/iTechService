source 'https://rubygems.org'

gem 'rails', '3.2.11'

gem 'pg'
gem 'thin'
gem "haml-rails"
gem 'jquery-rails'
gem 'jquery-rails-cdn'
gem 'simple_form'
gem 'json_builder'
gem 'devise'
gem 'cancan'
gem 'kaminari'
gem 'ancestry'
gem 'prawn'
gem 'carrierwave'
gem "mini_magick"
gem "ckeditor"
gem 'uuidtools'
gem 'exception_notification', git: 'git://github.com/alanjds/exception_notification.git'
gem 'private_pub'
gem 'twitter-bootstrap-rails', :git => 'git://github.com/seyhunak/twitter-bootstrap-rails.git'


# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails', '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'
  # See https://github.com/sstephenson/execjs#readme for more supported runtimes
  gem 'therubyracer', :platforms => :ruby
  gem "less-rails"
  gem 'uglifier', '>= 1.0.3'
  gem 'bootstrap-colorpicker-rails', :require => 'bootstrap-colorpicker-rails',
      :git => 'git://github.com/alessani/bootstrap-colorpicker-rails.git'
end


group :development do
  gem 'debugger'
  gem 'debugger-linecache'
  gem "debugger-pry", require: "debugger/pry"
  #gem 'linecache19', '>= 0.5.13'#, :git => 'https://github.com/robmathews/linecache19-0.5.13.git'
  #gem 'ruby-debug-base19x', '>= 0.11.30.pre10'
  #gem 'ruby-debug-ide', '>= 0.4.17.beta14'
  gem 'seed_dumper'
end

group :test do
  gem 'cucumber-rails'
  gem 'simplecov', require: false
end

group :development, :test do
  gem 'rspec-rails'
  gem 'capybara'
  gem 'database_cleaner'
  gem 'factory_girl_rails'
  #gem 'faker'
  #gem 'ffaker'
end

# To use ActiveModel has_secure_password
# gem 'bcrypt-ruby', '~> 3.0.0'

# To use Jbuilder templates for JSON
# gem 'jbuilder'

# Use unicorn as the app server
# gem 'unicorn'

# Deploy with Capistrano
# gem 'capistrano'

# To use debugger
# gem 'debugger'
