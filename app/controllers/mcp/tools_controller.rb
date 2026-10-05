# frozen_string_literal: true
module Mcp
  class ToolsController < ActionController::API
    before_action :authenticate
    def identity
      render json: {scopes: @credential.scope.split}
    end

    def call
      args = params[:arguments]
      raise Tools::Error.new('invalid_arguments', 'Ожидается объект arguments') unless args.is_a?(ActionController::Parameters)
      result = Tools.new(@credential.user, @credential.scope.split).call(params[:tool].to_s, args.to_unsafe_h)
      render json: {ok: true, data: result}
    rescue Tools::Error => e
      render json: {ok: false, error: {code: e.code, message: e.message}}, status: e.code == 'forbidden' ? :forbidden : :unprocessable_entity
    rescue ActiveRecord::RecordNotFound
      render json: {ok: false, error: {code: 'not_found', message: 'Заказ не найден'}}, status: :not_found
    rescue ActiveRecord::RecordInvalid
      render json: {ok: false, error: {code: 'validation_failed', message: 'АИС отклонила изменение; проверьте параметры в АИС'}}, status: :unprocessable_entity
    rescue StandardError => e
      Rails.logger.error("[MCP] tool failed: #{e.class.name}")
      render json: {ok: false, error: {code: 'ais_error', message: 'Ошибка АИС. Повторите запись с тем же request_key.'}}, status: :internal_server_error
    end

    private
    def authenticate
      return head :not_found unless Mcp::Configuration.enabled?
      raw = request.headers['Authorization'].to_s[/\ABearer ([A-Za-z0-9_-]+)\z/, 1]
      @credential = McpCredential.lookup(raw, 'access')
      unless @credential&.usable?
        response.headers['WWW-Authenticate'] = %(Bearer resource_metadata="#{Mcp::Configuration.origin}/.well-known/oauth-protected-resource/mcp")
        render json: {error: 'invalid_token'}, status: :unauthorized
      end
    end
  end
end
