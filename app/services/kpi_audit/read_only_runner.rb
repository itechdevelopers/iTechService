# frozen_string_literal: true

module KpiAudit
  # Owns the production transaction policy; Analyzer itself stays composable.
  # rubocop:disable Metrics/MethodLength
  class ReadOnlyRunner
    class NestedTransactionError < StandardError; end

    def self.call(connection: ActiveRecord::Base.connection, transaction_owner: ActiveRecord::Base)
      raise ArgumentError, 'block is required' unless block_given?
      if connection.open_transactions.positive?
        raise NestedTransactionError, 'ReadOnlyRunner requires a top-level transaction boundary'
      end

      result = nil
      transaction_owner.transaction do
        connection.execute('SET TRANSACTION READ ONLY') if connection.adapter_name.casecmp('PostgreSQL').zero?
        result = yield
        raise ActiveRecord::Rollback
      end
      result
    end
  end
  # rubocop:enable Metrics/MethodLength
end
