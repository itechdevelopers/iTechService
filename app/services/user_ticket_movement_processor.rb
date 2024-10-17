module UserTicketMovementProcessor
  class << self
    def process(movement)
      method_name = "process_#{movement.class.name.demodulize.underscore}"
      raise NotImplementedError, "No processor for #{movement.class.name}" unless respond_to?(method_name, true)

      ticket_number = WaitingClient.find(movement.waiting_client_id).ticket_number
      action = send(method_name, movement)
      {
        action: action,
        link: '',
        ticket_number: ticket_number,
        time: movement.created_at
      }
    end

    private

    def process_called(_movement)
      'Принял клиента с талоном'
    end

    def process_requeued_completed(_movement)
      'Вернул в очередь талон'
    end

    def process_requeued(_movement)
      'Передал талон в другое окно'
    end

    def process_manual(movement)
      "Передвинул талон с позиции #{movement.old_position} на
        позицию #{movement.new_position}"
    end
  end
end
