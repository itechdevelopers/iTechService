module ActionParams
  extend ActiveSupport::Concern

  included do
    helper_method :action_params
    helper_method :params_hash

    def action_params
      @action_params ||= params_hash.except(:host, :controller, :action, :format, :utf8)
    end
  end

  def params_hash
    @params_hash ||= params.to_unsafe_h.deep_symbolize_keys
  end
end
