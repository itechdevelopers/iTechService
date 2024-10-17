module AuditReport
  class TradeInDeviceCreateStrategy < BaseStrategy
    def matches?(audit)
      audit.auditable_type == 'TradeInDevice' &&
        audit.action == 'create'
    end

    def action(_audit)
      'принял устройство в Trade In'
    end

    def link(audit)
      Rails.application.routes.url_helpers.trade_in_device_path(audit.auditable)
    end
  end
end
