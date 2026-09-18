# frozen_string_literal: true

require 'spec_helper'
require 'active_support/all'
require 'pathname'

unless defined?(Rails)
  module Rails
    def self.root
      Pathname(__dir__).join('../..').expand_path
    end
  end
end

require Rails.root.join('app/services/hikvision/configuration_error').to_s
require Rails.root.join('app/services/hikvision/camera_catalog').to_s
require Rails.root.join('app/services/hikvision/camera_router').to_s
