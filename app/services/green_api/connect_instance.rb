# frozen_string_literal: true

module GreenApi
  # Подключение инстанса к каналу из Айса: проверить реквизиты у GREEN-API,
  # сохранить, направить уведомления инстанса в Айс и отвязать прежний
  # инстанс, если его сменили.
  class ConnectInstance
    Result = Struct.new(:status, :record, :error, :webhook, keyword_init: true) do
      def success?
        status == :connected
      end
    end

    def self.call(channel:, params:, user:)
      new(channel: channel, params: params, user: user).call
    end

    # params: api_url, media_url, id_instance, api_token. Пустой токен у уже
    # сохранённого инстанса значит «не менять».
    def initialize(channel:, params:, user:)
      @channel = Channel.fetch(channel)
      @params = params.to_h.symbolize_keys
      @user = user
    end

    def call
      record = @channel.instance_record || GreenApiInstance.new(channel: @channel.key)
      previous = record.persisted? ? record.credentials : @channel.env_credentials
      record.assign_attributes(@params.slice(:api_url, :media_url, :id_instance).merge(updated_by: @user))
      record.api_token = @params[:api_token] if @params[:api_token].present?
      return Result.new(status: :invalid, record: record) unless record.valid?

      state = InstanceApi.new(record.credentials).state
      unless state['http_code'] == 200 && state['stateInstance'].present?
        return Result.new(status: :rejected, record: record, error: InstanceApi.failure_text(state))
      end

      replaced = previous.configured? && previous.instance_id != record.id_instance
      keep_webhook_token(record, previous, replaced)
      record.save!
      detach(previous) if replaced
      webhook, error = InstanceApi.new(record.credentials)
                                  .ensure_webhook(webhook_url: @channel.webhook_url, webhook_token: record.webhook_token)
      Result.new(status: :connected, record: record, webhook: webhook, error: error)
    end

    private

    # Тот же инстанс — токен уведомлений прежний: уведомления, которые
    # GREEN-API уже отправил или повторяет, придут со старым токеном, и новый
    # их бы отверг. Другой инстанс — токен новый: прежний инстанс его знать не
    # должен. Нечитаемый (сменился ключ приложения) — тоже новый.
    def keep_webhook_token(record, previous, replaced)
      if replaced || record.webhook_token.blank?
        record.webhook_token = SecureRandom.hex(32)
      elsif record.new_record? && previous.webhook_token.present?
        record.webhook_token = previous.webhook_token
      end
    end

    def detach(previous)
      response = InstanceApi.new(previous).detach
      return if response['http_code'] == 200

      Rails.logger.warn("[GreenApi::ConnectInstance] #{@channel.key}: прежний инстанс #{previous.instance_id} " \
                        "не отвязан: #{InstanceApi.failure_text(response)}")
    end
  end
end
