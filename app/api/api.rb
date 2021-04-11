class API < Grape::API
  prefix 'api'
  format :json
  default_format :json
  REALM = 'ise_api'

  helpers do
    def logger
      API.logger
    end

    def auth_token_from_headers
      if (env['HTTP_AUTHORIZATION'] || headers['Authorization']).to_s[/^Token (.*)/]
        values = Hash[$1.split(',').map do |value|
          value.strip!                      # remove any spaces between commas and values
          key, value = value.split(/\=\"?/) # split key=value pairs
          value.chomp!('"')                 # chomp trailing " in value
          value.gsub!(/\\\"/, '"')          # unescape remaining quotes
          [key, value]
        end]
        #[values.delete("token"), values.with_indifferent_access]
        values.delete("token")
      end
    end

    def current_user
      if (token = auth_token_from_headers).present?
        @current_user ||= User.where(is_fired: [false, nil], authentication_token: token).first
        User.current = @current_user
      end
    end

    def authenticate!
      error!({error: 'Unauthorized'}, 401) unless current_user
    end

    def authorize(action, record)
      query = "#{action}?"
      policy = Pundit.policy(current_user, record)
      raise NotAuthorizedError, query: query, record: record, policy: policy unless policy.public_send(query)
      record
    end

    def find_record(scope, action)
      authorize action, scope.find(params[:id])
    end

    def present_record(record, presenter_class: nil, type: nil)
      presenter_class ||= "Entities::#{record.model_name.name}Entity".safe_constantize
      type ||= :full unless record.respond_to?(:any?)
      present record, with: presenter_class, type: type
    end

    def present_error(error, status: 400)
      error!({error: error}, status)
    end

    def present_record_errors(record)
      present_error record.errors.full_messages.to_sentence
    end

    def action_params
      return {} if params.empty?

      declared(params, include_parent_namespaces: false, include_missing: false).deep_symbolize_keys
    end
  end

  rescue_from Pundit::NotAuthorizedError do |e|
    Rack::Response.new({error: e.message}.to_json, 403).finish
  end

  rescue_from ActiveRecord::RecordNotFound do |exception|
    present_error exception.message, status: 404
  end

  mount TokenApi
  mount UserApi
  mount BarcodeApi
  mount ServiceJobApi
  mount ProductApi
  mount QuickOrderApi
  mount RepairApi
  mount OrderApi
end