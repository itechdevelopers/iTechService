class TranscriptionApi < Grape::API
  version 'v1', using: :path
  before { authenticate! }

  rescue_from Grape::Exceptions::ValidationErrors do |e|
    error!({ status: 400, detail: e.message }, 400)
  end

  resource :transcriptions do
    desc 'Create a call transcription'
    params do
      requires :call_unique_id, type: String
      requires :transcript_text, type: String
      requires :caller_number, type: String
      requires :call_date, type: DateTime
      optional :recording_url, type: String
    end
    post do
      Rails.logger.info "[TranscriptionApi] Creating transcription with params: #{declared(params).to_json}"

      authorize :create, CallTranscription

      transcription = CallTranscription.new(action_params)

      if transcription.save
        Rails.logger.info "[TranscriptionApi] Transcription created successfully: id=#{transcription.id}, client_id=#{transcription.client_id}"
        status 201
        present transcription, with: Entities::CallTranscriptionEntity
      else
        Rails.logger.warn "[TranscriptionApi] Validation failed: #{transcription.errors.full_messages.to_sentence}"
        error!({ status: 400, detail: transcription.errors.full_messages.to_sentence }, 400)
      end
    rescue ActiveRecord::RecordNotUnique
      Rails.logger.warn "[TranscriptionApi] Duplicate call_unique_id: #{params[:call_unique_id]}"
      error!({ status: 409, detail: 'A transcription with this call_unique_id already exists' }, 409)
    end
  end
end
