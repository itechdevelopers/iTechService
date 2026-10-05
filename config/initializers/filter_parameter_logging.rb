# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
Rails.application.config.filter_parameters += [:password]

# MCP credentials and tool payloads must never appear in request logs.
Rails.application.config.filter_parameters += [:authorization, :code, :code_verifier, :code_challenge,
  :access_token, :refresh_token, :token, :arguments, :state]
