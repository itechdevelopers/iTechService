# frozen_string_literal: true

module KpiAudit
  EconomicLine = Struct.new(:type, :id, :sale_id, :status, :posted, :return_sale, :value, :kind,
                            :occurred_at, :url, :related_kpi, keyword_init: true) do
    def to_h
      members.to_h { |name| [name, public_send(name)] }
    end
  end

  # Deduplicated, immutable monetary result of an investigation.
  class EconomicOutcome
    ATTRIBUTES = %i[sales payments posted_sales_count unposted_sales_count return_sales_count
                    gross_payments confirmed_returns net_confirmed_money money_received confidence explanation].freeze
    attr_reader(*ATTRIBUTES)

    def initialize(**attributes)
      ATTRIBUTES.each { |name| instance_variable_set("@#{name}", attributes[name]) }
      @sales = Array(@sales).freeze
      @payments = Array(@payments).freeze
      freeze
    end

    def to_h
      ATTRIBUTES.each_with_object({}) do |name, result|
        value = public_send(name)
        result[name] = value.is_a?(Array) ? value.map(&:to_h) : value
      end
    end
  end
end
