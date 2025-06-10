class CheckListResponsesProcessor
  def initialize(model, params_key = nil)
    @model = model
    @params_key = params_key || model.class.name.underscore
  end

  def process_create(params)
    check_list_responses_params = extract_check_list_params(params)
    return true unless check_list_responses_params

    @model.check_list_responses.clear
    
    check_list_responses_params.each do |_, response_attrs|
      next unless response_attrs[:check_list_id].present?

      response = find_or_initialize_response(response_attrs)
      response.responses = response_attrs[:responses] || {}

      response.save! if response.changed?
    end

    true
  end

  def process_update(params)
    check_list_responses_params = extract_check_list_params(params)
    return true unless check_list_responses_params

    submitted_check_list_ids = check_list_responses_params.values
                                                         .map { |attrs| attrs[:check_list_id] }
                                                         .compact

    check_list_responses_params.each do |_, response_attrs|
      next unless response_attrs[:check_list_id].present?

      existing_response = @model.check_list_responses.find_by(
        check_list_id: response_attrs[:check_list_id]
      )

      responses_data = response_attrs[:responses] || {}

      if existing_response
        existing_response.update!(responses: responses_data)
      else
        @model.check_list_responses.create!(
          check_list_id: response_attrs[:check_list_id],
          responses: responses_data,
          checkable: @model
        )
      end
    end

    true
  end

  def process(params, strategy: :create)
    case strategy
    when :create
      process_create(params)
    when :update
      process_update(params)
    else
      raise ArgumentError, "Unknown strategy: #{strategy}. Use :create or :update"
    end
  end

  private

  def extract_check_list_params(params)
    params.dig(@params_key.to_sym, :check_list_responses_attributes)
  end

  def find_or_initialize_response(response_attrs)
    @model.check_list_responses.find_or_initialize_by(
      check_list_id: response_attrs[:check_list_id]
    ) do |new_response|
      new_response.checkable = @model
    end
  end
end
