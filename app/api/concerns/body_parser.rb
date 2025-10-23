# frozen_string_literal: true

# Concern for parsing request bodies from 1C system
# Handles Windows line endings and extra whitespace that 1C may send
module BodyParser
  # Parse request body with proper cleanup for 1C integration
  # @return [Hash] Parsed JSON body as hash, or empty hash if parsing fails
  def parse_request_body
    # Get raw request body
    raw_body = request.body.read
    request.body.rewind # Rewind so Grape can read it again if needed

    # Clean Windows line endings and extra whitespace
    cleaned_body = clean_one_c_response(raw_body)

    # Parse JSON safely
    JSON.parse(cleaned_body)
  rescue JSON::ParserError => e
    Rails.logger.error "[BodyParser] Failed to parse request body: #{e.message}"
    Rails.logger.error "[BodyParser] Raw body: #{raw_body.inspect}"
    Rails.logger.error "[BodyParser] Cleaned body: #{cleaned_body.inspect}"
    {}
  end

  private

  # Clean response from 1C system
  # Removes Windows line endings (\r\n) and extra whitespace
  # @param body [String] Raw body string
  # @return [String] Cleaned body string
  def clean_one_c_response(body)
    return '' if body.blank?

    body.to_s
      .gsub("\r\n", "\n") # Convert Windows line endings to Unix
      .gsub("\r", "\n")   # Handle old Mac line endings too
      .strip              # Remove leading/trailing whitespace
  end
end