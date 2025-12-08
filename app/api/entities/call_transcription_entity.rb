class Entities::CallTranscriptionEntity < Grape::Entity
  expose :id do |transcription|
    transcription.id.to_s
  end
  expose :created_at
end
