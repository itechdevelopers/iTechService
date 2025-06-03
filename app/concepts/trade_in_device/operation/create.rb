class TradeInDevice::Create < BaseOperation
  class Present < BaseOperation
    step Policy.Pundit(TradeInDevicePolicy, :create?)
    failure :not_authorized!
    step Model(TradeInDevice, :new)
    step Contract.Build(constant: TradeInDevice::Contract)
  end

  step Nested(Present)
  step Contract.Validate(key: :trade_in_device)
  failure :contract_invalid!
  step Contract.Persist(method: :sync)
  step :assign_received_at
  success :assign_receiver
  success :assign_department
  step :process_check_list_responses!
  step :save_model
  step :assign_number
  step :success_message

  def process_check_list_responses!(model:, params:, **)
    check_list_responses_params = params.dig(:trade_in_device, :check_list_responses_attributes)
    return true unless check_list_responses_params

    model.check_list_responses.clear
    check_list_responses_params.each do |_, response_attrs|
      next unless response_attrs[:check_list_id].present?

      response = model.check_list_responses.find_or_initialize_by(
        check_list_id: response_attrs[:check_list_id]
      ) do |new_response|
        new_response.checkable = model
      end
      response.responses = response_attrs[:responses] || {}
    end

    true
  end

  def assign_received_at(model:, **)
    model.received_at = Time.current
  end

  def assign_receiver(model:, current_user:, **)
    model.receiver = current_user
  end

  def assign_department(model:, current_user:, **)
    model.department ||= current_user.department
  end

  def save_model(model:, **)
    model.save
  end

  def assign_number(model:, **)
    model.update(number: model.id)
  end

  def success_message(options, **)
    options['result.message'] = I18n.t('trade_in_device.created')
  end
end
