# frozen_string_literal: true

class CallTranscriptionsController < ApplicationController
  def index
    authorize CallTranscription
    @call_transcriptions = CallTranscription.order(call_date: :desc)
    @call_transcriptions = @call_transcriptions.where('call_date >= ?', parse_date(params[:date_from]).beginning_of_day) if params[:date_from].present?
    @call_transcriptions = @call_transcriptions.where('call_date <= ?', parse_date(params[:date_to]).end_of_day) if params[:date_to].present?
    @call_transcriptions = @call_transcriptions.search(params[:query]) if params[:query].present?
    @call_transcriptions = @call_transcriptions.page(params[:page])
  end

  def show
    @call_transcription = find_record CallTranscription
  end

  private

  def parse_date(date_string)
    Date.strptime(date_string, '%d.%m.%Y')
  rescue ArgumentError
    nil
  end
end
