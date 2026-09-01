# frozen_string_literal: true

module KpiAudit
  # Immutable accessor for explainable scoring and detector thresholds.
  class Configuration
    def self.load
      new(Rails.application.config_for(:kpi_audit).deep_symbolize_keys)
    end

    attr_reader :data

    def initialize(data)
      @data = data.deep_symbolize_keys.freeze
    end

    def fetch(*keys)
      keys.reduce(data) { |value, key| value.fetch(key.to_sym) }
    end
  end
end
