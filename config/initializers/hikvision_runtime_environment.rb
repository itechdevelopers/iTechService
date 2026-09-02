# frozen_string_literal: true

if Rails.env.production?
  require Rails.root.join('app/services/hikvision/runtime_environment').to_s
  Hikvision::RuntimeEnvironment.new.import!
end
