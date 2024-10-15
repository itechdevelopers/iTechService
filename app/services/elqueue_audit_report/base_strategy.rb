module ElqueueAuditReport
  class BaseStrategy
    def matches?(audit)
      raise NotImplementedError
    end

    def process(audit)
      {
        action: action(audit),
        link: link(audit),
        ticket_number: ticket_number(audit)
      }
    end

    def action(audit)
      raise NotImplementedError
    end

    def link(audit)
      raise NotImplementedError
    end

    def ticket_number(audit)
      WaitingClient.find(audit.metadata['ticket_id']).ticket_number
    end
  end
end
