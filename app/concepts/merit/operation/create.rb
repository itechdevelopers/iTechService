class Merit::Create < BaseOperation
  class Present < BaseOperation
    step Policy::Pundit(MeritPolicy, :create?)
    failure :not_authorized!
    step Model(Merit, :new)
    success ->(params:, model:, current_user:, **) {
      model.recipient_id = params[:user_id]
      model.issued_by_id = current_user.id
    }
    step Contract::Build(constant: Merit::Contract::Base)
  end

  step Nested(Present)
  step Contract::Validate(key: :merit)
  failure :contract_invalid!
  step Contract::Persist()
end
