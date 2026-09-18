# frozen_string_literal: true

module KpiAudit
  # Shared, user-isolated storage for completed audit runs.
  class RunStore
    NAMESPACE = 'kpi-audit:runs'

    def initialize(redis: nil)
      @redis = redis
    end

    def write(user_id, run_id, value, expires_in:)
      with_redis { |redis| redis.set(key(user_id, run_id), Marshal.dump(value), ex: expires_in.to_i) }
    end

    def read(user_id, run_id)
      payload = with_redis { |redis| redis.get(key(user_id, run_id)) }
      payload && Marshal.load(payload) # rubocop:disable Security/MarshalLoad
    rescue TypeError, ArgumentError
      nil
    end

    private

    def key(user_id, run_id)
      "#{NAMESPACE}:user:#{Integer(user_id)}:#{run_id}"
    end

    def with_redis(&block)
      return @redis.call(&block) if @redis.respond_to?(:call)
      return yield(@redis) if @redis

      Sidekiq.redis(&block)
    end
  end
end
