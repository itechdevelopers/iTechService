ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)
ENV['EXECJS_RUNTIME'] ||= 'Node'
ENV['PATH'] = "/home/deploy/.nvm/versions/node/v14.21.3/bin/node:#{ENV['PATH']}"

require 'bundler/setup' # Set up gems listed in the Gemfile.
