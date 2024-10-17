module AuditReport
  class TechnicianBaseStrategy < BaseStrategy
    def process(audit)
      {
        action: action(audit),
        link: link(audit),
        time: audit.created_at
      }
    end
  end
end
