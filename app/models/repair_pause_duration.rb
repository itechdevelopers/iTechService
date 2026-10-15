# Срок паузы ремонта: число и единица — из быстрой кнопки или своего ввода.
# Пустое число означает паузу без срока, это допустимо.
class RepairPauseDuration
  UNITS = {
    'minutes' => 1.minute,
    'hours' => 1.hour,
    'days' => 1.day
  }.freeze

  PRESETS = [
    [30, 'minutes'],
    [1, 'hours'],
    [2, 'hours'],
    [4, 'hours'],
    [1, 'days'],
    [3, 'days']
  ].freeze

  # Ограничение ловит опечатки вроде «300 дней»: по сроку ставится отложенная
  # задача автоснятия, и такая пауза фактически стала бы бессрочной.
  MAX_DAYS = 60

  attr_reader :amount, :unit

  def initialize(amount:, unit:)
    raw = amount.to_s.strip
    @blank = raw.empty?
    @amount = raw.match?(/\A\d+\z/) ? raw.to_i : nil
    @unit = unit.to_s
  end

  def blank?
    @blank
  end

  def error
    return if blank?
    return I18n.t('service_jobs.repair_status.pause_duration.invalid_amount') unless amount&.positive?
    return I18n.t('service_jobs.repair_status.pause_duration.invalid_unit') unless UNITS.key?(unit)

    I18n.t('service_jobs.repair_status.pause_duration.too_long', days: MAX_DAYS) if raw_length > MAX_DAYS.days
  end

  def valid?
    error.nil?
  end

  def length
    return if blank? || !valid?

    raw_length
  end

  private

  def raw_length
    amount * UNITS.fetch(unit)
  end
end
