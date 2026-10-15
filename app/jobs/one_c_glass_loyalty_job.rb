# frozen_string_literal: true
class OneCGlassLoyaltyJob < ApplicationJob
  queue_as :default

  def perform(digest, attempt = 0)
    return unless digest.to_s.match?(/\A[0-9a-f]{64}\z/)
    prefix = OneCGlassLoyalty::PREFIX
    token = SecureRandom.hex(16)
    locked = Sidekiq.redis { |r| r.set("#{prefix}:lock", token, nx: true, ex: 150) }
    unless locked
      if attempt < 20
        self.class.set(wait: 5.seconds).perform_later(digest, attempt + 1)
      else
        fail_lookup(prefix, digest, 'Сервис занят. Повторите поиск через минуту.')
      end
      return
    end
    begin
      phone = Sidekiq.redis { |r| r.get("#{prefix}:input:#{digest}") }
      return unless phone
      data = OneCGlassLoyalty.fetch(phone)
      Sidekiq.redis do |r|
        r.set("#{prefix}:result:#{digest}", { cached_at: Time.now.to_i, data: data }.to_json, ex: OneCGlassLoyalty::KEEP_FOR)
        r.del("#{prefix}:error:#{digest}")
      end
    rescue StandardError
      # Retain the previous successful result. Do not log exception bodies or phone numbers.
      fail_lookup(prefix, digest, 'Не удалось обновить историю из 1С. Предыдущие данные, если есть, сохранены; повторите поиск позже.')
    ensure
      Sidekiq.redis do |r|
        r.del("#{prefix}:pending:#{digest}", "#{prefix}:input:#{digest}")
        r.eval("if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end", keys: ["#{prefix}:lock"], argv: [token])
      end
    end
  end

  private

  def fail_lookup(prefix, digest, message)
    Sidekiq.redis do |r|
      r.set("#{prefix}:error:#{digest}", message, ex: 300)
      r.del("#{prefix}:pending:#{digest}", "#{prefix}:input:#{digest}")
    end
  end
end
