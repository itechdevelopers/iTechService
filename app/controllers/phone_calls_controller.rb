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
    numbers = @phone_calls.flat_map { |call| [call.caller_number, call.called_number] }.map { |value| Telephony::Number.normalize(value) }.compact.uniq
    @call_clients = Hash.new { |hash, number| hash[number] = [] }
    unless numbers.empty?
      variants = numbers.flat_map { |number| [number, '8' + number[1..-1], number[1..-1]] }
      cache_key = 'telephony/client-matches/' + Digest::SHA256.hexdigest(numbers.sort.join(','))
      ids = Rails.cache.fetch(cache_key, expires_in: 1.minute) do
        Client.where("REGEXP_REPLACE(full_phone_number, '[^0-9]', '', 'g') IN (:numbers) OR REGEXP_REPLACE(phone_number, '[^0-9]', '', 'g') IN (:numbers) OR REGEXP_REPLACE(contact_phone, '[^0-9]', '', 'g') IN (:numbers)", numbers: variants).limit(500).pluck(:id)
      end
      Client.where(id: ids).each do |client|
        next unless policy(client).show?
        [client.full_phone_number, client.phone_number, client.contact_phone].each do |value|
          number = Telephony::Number.normalize(value)
          if !number && value.to_s.match?(/\A[\d\s()\-]+\z/) && value.to_s.gsub(/\D/, '').length == 10
            number = Telephony::Number.normalize('7' + value.to_s)
          end
          @call_clients[number] << client if numbers.include?(number) && !@call_clients[number].include?(client)
        end
      end
    end
    @sync_states = TelephonySyncState.all.index_by(&:source)
    render partial: 'history' if params[:fragment] == '1'

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
