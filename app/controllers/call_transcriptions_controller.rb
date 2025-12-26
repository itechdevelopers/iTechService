# frozen_string_literal: true

class CallTranscriptionsController < ApplicationController
  def index
    authorize CallTranscription
    @call_transcriptions = CallTranscription.order(call_date: :desc).page(params[:page])
  end

  def show
    @call_transcription = find_record CallTranscription
  end
end
