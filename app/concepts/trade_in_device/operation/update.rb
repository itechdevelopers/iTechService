class TradeInDevice::Update < BaseOperation
  class Present < BaseOperation
    step Model(TradeInDevice, :find_by)
    failure :record_not_found!
    step Policy.Pundit(TradeInDevicePolicy, :update?)
    failure :not_authorized!
    step Contract.Build(constant: TradeInDevice::Contract)
  end

  step Nested(Present)
  step Contract.Validate(key: :trade_in_device)
  failure :contract_invalid!
  step :process_check_list_responses!
  step Contract.Persist
  step ->(options, **) { options['result.message'] = I18n.t('trade_in_device.updated') }

  def process_check_list_responses!(model:, params:, **)
    check_list_responses_params = params.dig(:trade_in_device, :check_list_responses_attributes)
    return true unless check_list_responses_params

    submitted_check_list_ids = check_list_responses_params.values
                                                         .map { |attrs| attrs[:check_list_id] }
                                                         .compact

    check_list_responses_params.each do |_, response_attrs|
      next unless response_attrs[:check_list_id].present?

      existing_response = model.check_list_responses.find_by(
        check_list_id: response_attrs[:check_list_id]
      )

      responses_data = response_attrs[:responses] || {}

      if existing_response
        existing_response.update(responses: responses_data)
      else
        model.check_list_responses.build(
          check_list_id: response_attrs[:check_list_id],
          responses: responses_data,
          checkable: model
        )
      end
    end

    true
  end
end
