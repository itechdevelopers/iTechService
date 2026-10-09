# frozen_string_literal: true

module GreenApi
  # Что сейчас с инстансом канала: подключён ли аккаунт, какой у него номер
  # и идут ли уведомления в Айс. Для страницы управления инстансами.
  class InstanceStatus
    Result = Struct.new(:credentials, :state, :phone, :suspended_until, :webhook, :webhook_url, :error,
                        keyword_init: true)

    READ_TIMEOUT = 10

    def self.call(channel)
      new(channel).call
    end

    def initialize(channel)
      @channel = Channel.fetch(channel)
    end

    def call
      credentials = @channel.credentials
      return Result.new(credentials: credentials) unless credentials.configured?

      api = InstanceApi.new(credentials, read_timeout: READ_TIMEOUT)
      account = api.account(@channel.account_method)
      unless account['http_code'] == 200
        return Result.new(credentials: credentials, error: InstanceApi.failure_text(account))
      end

      settings = api.current_settings
      Result.new(credentials: credentials, state: account['stateInstance'].to_s, phone: account['phone'].presence,
                 suspended_until: account['suspendedUntil'].presence && Time.zone.at(account['suspendedUntil'].to_i),
                 webhook: webhook_state(settings, credentials), webhook_url: settings['webhookUrl'].presence)
    end

    private

    # :ours — уведомления идут в Айс; :token — адрес наш, но токен другой
    # (Айс такие уведомления отвергнет); :elsewhere — на чужой адрес; :off —
    # никуда; :no_host — Айс не знает собственного адреса.
    def webhook_state(settings, credentials)
      return :unknown unless settings['http_code'] == 200
      return :no_host if @channel.webhook_url.nil?

      current = settings['webhookUrl'].to_s
      return :off if current.blank?
      return :elsewhere if current != @channel.webhook_url

      settings['webhookUrlToken'].to_s == credentials.webhook_token ? :ours : :token
    end
  end
end
