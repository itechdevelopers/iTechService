class Fault::Create < BaseOperation
  class Present < BaseOperation
    step Policy::Pundit(FaultPolicy, :create?)
    failure :not_authorized!
    step Model(Fault, :new)
    success ->(params:, model:, **) { model.causer_id = params[:user_id] }
    step Contract::Build(constant: Fault::Contract::Base)
  end

  step Nested(Present)
  step Contract::Validate(key: :fault)
  step :calculate_penalty
  failure :contract_invalid!
  step Contract::Persist()

  private

  def calculate_penalty(options)
    kind = FaultKind.find(options['contract.default'].kind_id)

    if kind.financial?
      true
    else
      date = options['contract.default'].date.to_date
      causer_id = options['contract.default'].causer_id
      count = Fault.active.by_causer(causer_id).by_kind(kind).on_date(date).count

      if count < kind.penalties.length
        options['contract.default'].penalty = kind.penalties[count]
      else
        options['contract.default'].penalty = kind.penalties[-1]
      end
    end
  end
end
