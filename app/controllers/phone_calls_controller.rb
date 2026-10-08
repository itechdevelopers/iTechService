# frozen_string_literal: true
class PhoneCallsController < ApplicationController
  def index
    authorize PhoneCall
    @phone_calls = PhoneCall.newest.includes(:answered_user, :caller_user)
    if params[:number].present?
      number = Telephony::Number.normalize(params[:number]) || params[:number].to_s.gsub(/\D/, '')
      @phone_calls = @phone_calls.where('caller_number = :number OR called_number = :number OR answered_extension = :number', number: number)
    end
    @phone_calls = @phone_calls.page(params[:page]).per(100)
  end
  def audio
    call = authorize PhoneCall.find(params[:id])
    # Use the same authenticated SFTP audio mechanism as transcriptions, without
    # storing SFTP credentials or exposing its URL to the browser.
    Telephony::Recording.new(call.recording_path).send_to(self)
  rescue Telephony::Recording::Unavailable
    redirect_to phone_calls_path, alert: 'Запись разговора пока недоступна.'
  end
end
