# frozen_string_literal: true

# Официальный курс доллара ЦБ РФ: CbrUsdRate.call → { rate: BigDecimal, date: Date }
# или nil, если ЦБ недоступен. После ~11:30 МСК XML_daily.asp отдаёт курс, уже
# установленный на завтра, поэтому дату берём из ответа, а не Date.current.
class CbrUsdRate
  URL = 'https://www.cbr.ru/scripts/XML_daily.asp'
  USD_ID = 'R01235'
  CACHE_KEY = 'cbr_usd_rate'
  CACHE_TTL = 1.hour
  # Неудачу тоже кэшируем, но коротко: курс подставляется в каждую строку
  # таблицы, и без этого лежащий ЦБ стоил бы таймаута на каждой.
  FAILURE_TTL = 5.minutes
  TIMEOUT = 3

  def self.call
    new.call
  end

  # Rails 5.1: fetch кэширует и nil (skip_nil появился в 6.0), поэтому неудачу
  # кладём явным false — read отличает её от пустого кэша.
  def call
    cached = Rails.cache.read(CACHE_KEY)
    return cached.presence unless cached.nil?

    rate = fetch
    Rails.cache.write(CACHE_KEY, rate || false, expires_in: rate ? CACHE_TTL : FAILURE_TTL)
    rate
  end

  private

  def fetch
    response = HTTParty.get(URL, timeout: TIMEOUT)
    return unless response.success?

    # Ответ в windows-1251 — Nokogiri берёт кодировку из XML-пролога.
    doc = Nokogiri::XML(response.body)
    valute = doc.at_xpath("//Valute[@ID='#{USD_ID}']")
    return unless valute

    value = BigDecimal(valute.at('Value').text.tr(',', '.')) / valute.at('Nominal').text.to_i
    { rate: value.round(4), date: Date.strptime(doc.root['Date'], '%d.%m.%Y') }
  rescue StandardError => e
    Rails.logger.warn("CbrUsdRate: #{e.class}: #{e.message}")
    nil
  end
end
