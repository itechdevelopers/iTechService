# frozen_string_literal: true
class PhoneCallsController < ApplicationController
  def index
    authorize PhoneCall
    @phone_calls = PhoneCall.newest.includes(:answered_user, :caller_user)
    if params[:number].present?
      number = Telephony::Number.normalize(params[:number]) || params[:number].to_s.gsub(/\D/, '')
      @phone_calls = @phone_calls.where('caller_number = :number OR called_number = :number OR answered_extension = :number', number: number)
    end
    @phone_calls = @phone_calls.where.not(direction: 'internal') if params[:external_only] == '1'
    @phone_calls = @phone_calls.where(direction: params[:direction]) if PhoneCall::DIRECTIONS.include?(params[:direction])
    @phone_calls = @phone_calls.where(status: params[:status]) if PhoneCall::STATUSES.include?(params[:status])
    @phone_calls = @phone_calls.where('started_at >= ?', Date.iso8601(params[:date_from]).beginning_of_day) if params[:date_from].present?
    @phone_calls = @phone_calls.where('started_at < ?', Date.iso8601(params[:date_to]).tomorrow.beginning_of_day) if params[:date_to].present?
    @directory_entries = PhoneLabel.includes(:department, :user).order(:label)
    @number_groups = PhoneLabel.where.not(group_name: [nil, '']).distinct.order(:group_name).pluck(:group_name)
    selected = @directory_entries
    selected = selected.where(group_name: params[:group_name]) if params[:group_name].present?
    selected = selected.where(id: params[:directory_id]) if params[:directory_id].present?
    selected = selected.where('phone_labels.department_id = :id OR phone_labels.user_id IN (SELECT id FROM users WHERE department_id = :id)', id: params[:department_id]) if params[:department_id].present?
    selected = selected.where(user_id: params[:employee_id]) if params[:employee_id].present?
    if params.values_at(:directory_id, :department_id, :employee_id, :group_name).any?(&:present?)
      linked = User.all
      linked = linked.where(department_id: params[:department_id]) if params[:department_id].present?
      linked = linked.where(id: params[:employee_id]) if params[:employee_id].present?
      numbers = selected.pluck(:phone_number)
      numbers += linked.pluck(:telephony_extension, :pbx_extension).flatten.compact unless params[:directory_id].present? || params[:group_name].present?
      @phone_calls = @phone_calls.where("caller_number IN (:numbers) OR called_number IN (:numbers) OR answered_extension IN (:numbers) OR EXISTS (SELECT 1 FROM jsonb_array_elements(phone_calls.legs) AS leg WHERE leg->>'number' IN (:numbers))", numbers: numbers)
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
    visible_numbers = @phone_calls.flat_map { |call| [call.caller_number, call.called_number, call.answered_extension] + call.legs.map { |leg| leg['number'] } }.compact.uniq
    @number_labels = @directory_entries.where(phone_number: visible_numbers).index_by(&:phone_number)
    @departments = Department.order(:name)
    @employees = User.active.staff.order(:surname, :name)
    @sync_states = TelephonySyncState.all.index_by(&:source)
    render partial: 'history' if params[:fragment] == '1'
  rescue ArgumentError
    if params[:fragment] == '1'
      head :unprocessable_entity
    else
      redirect_to phone_calls_path(defaults: '1'), alert: 'Проверьте даты фильтра.'
    end
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
