module ElqueueAuditReport
  class StrategyFactory
    @strategies = []

    class << self
      attr_reader :strategies

      def register(strategy)
        @strategies << strategy.new
      end

      def process_audit(audit)
        strategy = @strategies.find { |s| s.matches?(audit) }
        strategy&.process(audit)
      end
    end
  end
end
