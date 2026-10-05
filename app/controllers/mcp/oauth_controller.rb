# frozen_string_literal: true
module Mcp
  class OauthController < ActionController::Base
    protect_from_forgery with: :exception
    skip_before_action :verify_authenticity_token, only: [:token, :revoke]
    before_action :enabled
    before_action :authenticate_user!, only: [:authorize, :consent]
    after_action :no_store
    rescue_from Oauth::Error, with: :oauth_error

    def metadata
      origin = Mcp::Configuration.origin
      render json: {issuer: origin, authorization_endpoint: "#{origin}/mcp/oauth/authorize",
        token_endpoint: "#{origin}/mcp/oauth/token", revocation_endpoint: "#{origin}/mcp/oauth/revoke",
        response_types_supported: ['code'], grant_types_supported: ['authorization_code', 'refresh_token'],
        token_endpoint_auth_methods_supported: ['none'], code_challenge_methods_supported: ['S256'],
        scopes_supported: Mcp::Configuration::SCOPES, authorization_response_iss_parameter_supported: true}
    end

    def authorize
      raise Oauth::Error, 'access_denied' if current_user.is_fired?
      @oauth = Oauth.authorization_parameters(params.permit!.to_h)
      # The signed/encrypted cookie binds consent to the validated request and login session.
      session[:mcp_consent] = @oauth.merge('expires_at' => 10.minutes.from_now.to_i, 'user_id' => current_user.id)
      render :authorize, layout: false
    end

    def consent
      saved = session.delete(:mcp_consent)
      raise Oauth::Error, 'invalid_request' unless saved && saved['expires_at'].to_i > Time.current.to_i && saved['user_id'] == current_user.id
      @oauth = Oauth.authorization_parameters(saved)
      raise Oauth::Error, 'access_denied' if current_user.is_fired?
      response = {state: @oauth['state'], iss: Mcp::Configuration.origin}
      if params[:approve] == 'yes'
        response[:code] = McpCredential.issue!(kind: 'code', user: current_user, client_id: @oauth['client_id'],
          resource: @oauth['resource'], scope: @oauth['scope'], redirect_uri: @oauth['redirect_uri'],
          code_challenge: @oauth['code_challenge'], expires_at: 5.minutes.from_now)
      else
        response[:error] = 'access_denied'
      end
      uri = URI.parse(@oauth['redirect_uri'])
      existing = URI.decode_www_form(uri.query.to_s)
      uri.query = URI.encode_www_form(existing + response.to_a)
      redirect_to uri.to_s
    end

    def token
      render json: Oauth.exchange(params)
    end

    def revoke
      credential = McpCredential.lookup(params[:token], 'refresh') || McpCredential.lookup(params[:token], 'access')
      if credential && params[:client_id] == credential.client_id
        # Disconnect all credentials for this user's client, including outstanding access tokens.
        McpCredential.where(user_id: credential.user_id, client_id: credential.client_id).update_all(revoked_at: Time.current)
      end
      head :ok
    end

    private
    def enabled
      head :not_found unless Mcp::Configuration.enabled?
    end
    def no_store
      response.headers['Cache-Control'] = 'no-store'
      response.headers['Pragma'] = 'no-cache'
      response.headers['Referrer-Policy'] = 'no-referrer'
    end
    def oauth_error(error)
      render json: {error: error.message}, status: :bad_request
    end
  end
end
