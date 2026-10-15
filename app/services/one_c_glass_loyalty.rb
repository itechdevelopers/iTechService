# frozen_string_literal: true
require 'open3'
require 'timeout'
require 'openssl'

class OneCGlassLoyalty
  class InvalidPhone < StandardError; end
  PREFIX = 'one-c:glass:v1'.freeze
  FRESH_FOR = 90
  KEEP_FOR = 24.hours.to_i

  def self.normalize(phone)
    text = phone.to_s
    raise InvalidPhone, 'Введите полный российский номер телефона.' if text.length > 40 || text.match?(/[^0-9+()\s-]/)
    digits = text.gsub(/\D/, '')
    digits = "7#{digits}" if digits.length == 10
    digits[0] = '7' if digits.length == 11 && digits.start_with?('8')
    raise InvalidPhone, 'Введите 10 цифр либо 11 цифр с 7/8.' unless digits.match?(/\A7\d{10}\z/)
    digits
  end

  def self.key(phone)
    OpenSSL::HMAC.hexdigest('SHA256', Rails.application.secrets.secret_key_base, phone)
  end

  def self.start(phone, user_id)
    phone = normalize(phone)
    digest = key(phone)
    Sidekiq.redis do |redis|
      throttle = "#{PREFIX}:rate:#{user_id}:#{Time.now.to_i / 60}"
      attempts = redis.incr(throttle)
      redis.expire(throttle, 120) if attempts == 1
      raise InvalidPhone, 'Слишком частые поиски. Подождите минуту.' if attempts > 10
      cached = redis.get("#{PREFIX}:result:#{digest}")
      return digest if cached && Time.now.to_i - JSON.parse(cached).fetch('cached_at') < FRESH_FOR
      if redis.set("#{PREFIX}:pending:#{digest}", 'queued', nx: true, ex: 300)
        redis.set("#{PREFIX}:input:#{digest}", phone, ex: 300)
        redis.del("#{PREFIX}:error:#{digest}")
        begin
          OneCGlassLoyaltyJob.perform_later(digest)
        rescue StandardError
          redis.del("#{PREFIX}:pending:#{digest}", "#{PREFIX}:input:#{digest}")
          raise
        end
      end
    end
    digest
  end

  def self.read(digest)
    return {} unless digest.to_s.match?(/\A[0-9a-f]{64}\z/)
    Sidekiq.redis do |redis|
      raw = redis.get("#{PREFIX}:result:#{digest}")
      cached = raw && JSON.parse(raw)
      pending = redis.exists?("#{PREFIX}:pending:#{digest}")
      error = redis.get("#{PREFIX}:error:#{digest}")
      { result: cached && cached['data'], stale: cached && Time.now.to_i - cached['cached_at'] >= FRESH_FOR,
        pending: pending, error: error, expired: !cached && !pending && !error }
    end
  end

  def self.fetch(phone)
    Open3.popen3(ENV.fetch('AIS_ONE_C_PYTHON', 'python3'), Rails.root.join('script/one_c/glass_loyalty.py').to_s, pgroup: true) do |stdin, stdout, stderr, process|
      begin
        # No credentials or phone in argv/logs. Python emits only bounded JSON.
        stderr.close
        Timeout.timeout(120) do
          stdin.write({ phone: phone }.to_json); stdin.close
          output = stdout.read(2_000_001)
          raise 'oversize' if output.bytesize > 2_000_000
          result = JSON.parse(output)
          raise 'incomplete' unless process.value.success? && result['complete'] == true
          result
        end
      ensure
        unless process.join(0)
          Process.kill('KILL', -process.pid) rescue Errno::ESRCH
          process.join
        end
      end
    end
  end
end
