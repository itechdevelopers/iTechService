class Merit::Exchange < BaseOperation
  RATE = 2 # сколько плюсов «съедает» один минус

  step Model(Fault, :find_by)
  failure :record_not_found!
  step Policy::Pundit(FaultPolicy, :exchange?)
  failure :not_authorized!
  step :enough_merits?
  failure :not_enough_merits!
  step :exchange!

  private

  # ВАЖНО: step-методы здесь объявлены с arity 1 (один позиционный `options`),
  # потому что Trailblazer 0.0.13 (Option::KW#call_method) корректно вызывает только
  # методы с arity == 1; сигнатура `(options, **)` уходит в багованный `**to_hash`-путь.
  # Модель достаём через строковый ключ options['model'] (как Fault::Create#calculate_penalty).
  def enough_merits?(options)
    available_merits(options['model']).count >= RATE
  end

  def exchange!(options)
    fault = options['model']
    Fault.transaction do
      available_merits(fault).order(:date, :created_at).limit(RATE).each do |merit|
        merit.update!(exchanged: true, exchanged_at: Time.current, fault_id: fault.id)
      end
      fault.update!(exchanged: true, exchanged_at: Time.current)
    end
  end

  def available_merits(fault)
    Merit.by_recipient(fault.causer_id).available
  end

  def not_enough_merits!(options)
    options['result.message'] = I18n.t('faults.exchange.not_enough')
    Railway.fail_fast!
  end
end
