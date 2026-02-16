# frozen_string_literal: true

class LinkOrphanTranscriptionsJob < ApplicationJob
  queue_as :default

  def perform
    result = ActiveRecord::Base.connection.execute(<<-SQL.squish)
      UPDATE call_transcriptions
      SET client_id = matched_clients.id,
          updated_at = NOW()
      FROM (
        SELECT DISTINCT ON (call_transcriptions.id)
          call_transcriptions.id AS transcription_id,
          clients.id
        FROM call_transcriptions
        INNER JOIN clients ON (
          clients.full_phone_number = call_transcriptions.caller_number
          OR clients.phone_number = call_transcriptions.caller_number
          OR clients.contact_phone = call_transcriptions.caller_number
        )
        WHERE call_transcriptions.client_id IS NULL
      ) AS matched_clients
      WHERE call_transcriptions.id = matched_clients.transcription_id
    SQL

    Rails.logger.info "[LinkOrphanTranscriptions] Linked #{result.cmd_tuples} transcriptions to clients"
  end
end
