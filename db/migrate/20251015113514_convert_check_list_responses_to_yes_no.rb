class ConvertCheckListResponsesToYesNo < ActiveRecord::Migration[5.1]
  def up
    # Convert existing check list responses from "true" values to "yes"
    # This migration preserves backward compatibility
    CheckListResponse.find_each do |response|
      next unless response.responses.is_a?(Hash)

      updated_responses = {}
      response.responses.each do |item_id, value|
        # Convert "true" string to "yes"
        if value == "true"
          updated_responses[item_id] = "yes"
        elsif value == "false" || value == false
          # Explicit false values become "no"
          updated_responses[item_id] = "no"
        elsif value.present?
          # Keep any other existing value (in case there are already yes/no values)
          updated_responses[item_id] = value
        end
      end

      # Only update if there were changes
      if updated_responses != response.responses
        response.update_column(:responses, updated_responses)
        puts "Updated CheckListResponse ##{response.id}: #{response.responses.count} items converted"
      end
    end

    puts "Migration completed: Converted check list responses to yes/no format"
  end

  def down
    # Convert back from "yes"/"no" to "true"/nil format
    CheckListResponse.find_each do |response|
      next unless response.responses.is_a?(Hash)

      updated_responses = {}
      response.responses.each do |item_id, value|
        # Only keep "yes" values as "true", remove "no" values
        if value == "yes"
          updated_responses[item_id] = "true"
        elsif value == "true"
          # Keep existing "true" values
          updated_responses[item_id] = "true"
        end
        # "no" values are removed (not stored in the old format)
      end

      # Only update if there were changes
      if updated_responses != response.responses
        response.update_column(:responses, updated_responses)
        puts "Reverted CheckListResponse ##{response.id}: #{response.responses.count} items converted back"
      end
    end

    puts "Rollback completed: Reverted check list responses to checkbox format"
  end
end
