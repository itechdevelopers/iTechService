module AuditReport
  class BaseStrategy
    def matches?(audit)
      raise NotImplementedError
    end

    def process(audit)
      {
        action: action(audit),
        link: link(audit),
        ticket_number: ticket_number(audit),
        time: audit.created_at
      }
    end

    def action(audit)
      raise NotImplementedError
    end

    def link(audit)
      raise NotImplementedError
    end

    def ticket_number(audit)
      return '' unless audit.metadata['ticket_id']

      WaitingClient.find(audit.metadata['ticket_id']).ticket_number
    end
  end
end
