# frozen_string_literal: true
require 'base64'

module Mcp
  class Oauth
    class Error < StandardError; end
    def self.authorization_parameters(params)
      p = params.to_h.stringify_keys.slice('client_id', 'redirect_uri', 'response_type', 'scope', 'state', 'resource', 'code_challenge', 'code_challenge_method')
      scopes = p['scope'].to_s.split.uniq
      valid = p['client_id'] == Configuration.client_id &&
        Configuration.redirect_uris.include?(p['redirect_uri']) && p['response_type'] == 'code' &&
        p['resource'] == Configuration.resource && p['code_challenge_method'] == 'S256' &&
        p['code_challenge'].to_s.match?(/\A[A-Za-z0-9_-]{43}\z/) &&
        scopes.include?('ais:read') && (scopes - Configuration::SCOPES).empty? && p['state'].to_s.bytesize <= 1024
      raise Error, 'invalid_request' unless valid
      p.merge('scope' => scopes.sort.join(' '))
    end

    def self.exchange(params)
      kind = {'authorization_code' => 'code', 'refresh_token' => 'refresh'}[params[:grant_type]]
      raise Error, 'unsupported_grant_type' unless kind
      credential = McpCredential.lookup(params[kind == 'code' ? :code : :refresh_token], kind)
      raise Error, 'invalid_grant' unless credential
      result = credential.with_lock do
        if kind == 'refresh' && credential.revoked_at && params[:client_id] == credential.client_id && params[:resource] == credential.resource
          McpCredential.where(family_id: credential.family_id).update_all(revoked_at: Time.current)
          next :replayed_refresh
        end
        raise Error, 'invalid_grant' unless credential.usable? && params[:client_id] == credential.client_id && params[:resource] == credential.resource
        if kind == 'code'
          verifier = params[:code_verifier].to_s
          challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
          raise Error, 'invalid_grant' unless verifier.match?(/\A[A-Za-z0-9._~-]{43,128}\z/) &&
            params[:redirect_uri] == credential.redirect_uri && ActiveSupport::SecurityUtils.secure_compare(challenge, credential.code_challenge)
        elsif params[:scope].present? && params[:scope].split.sort != credential.scope.split.sort
          raise Error, 'invalid_scope'
        end
        credential.update!(revoked_at: Time.current)
        common = {user: credential.user, client_id: credential.client_id, resource: credential.resource, scope: credential.scope, family_id: credential.family_id}
        {access_token: McpCredential.issue!(**common, kind: 'access', expires_at: 1.hour.from_now),
         refresh_token: McpCredential.issue!(**common, kind: 'refresh', expires_at: 30.days.from_now),
         token_type: 'Bearer', expires_in: 3600, scope: credential.scope}
      end
      raise Error, 'invalid_grant' if result == :replayed_refresh
      result
    end
  end
end
