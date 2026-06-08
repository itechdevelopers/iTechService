class Merit::Unexchange < BaseOperation
  step Model(Fault, :find_by)
  failure :record_not_found!
  step Policy::Pundit(FaultPolicy, :unexchange?)
  failure :not_authorized!
  step :unexchange!

  private

  # Откат обмена (только superadmin). Возвращаем ровно те плюсы, что были потрачены
  # на этот минус (связь через merits.fault_id), и снимаем пометку с самого минуса.
  # arity 1 (один позиционный options) — см. PLAYBOOK «Тестирование Trailblazer-операций»
  # и комментарий в Merit::Exchange: метод с arity == 1 единственный корректный путь
  # в Option::KW#call_method для trailblazer-operation 0.0.13.
  def unexchange!(options)
    fault = options['model']
    Fault.transaction do
      Merit.where(fault_id: fault.id)
           .update_all(exchanged: false, exchanged_at: nil, fault_id: nil)
      fault.update!(exchanged: false, exchanged_at: nil)
    end
  end
end
