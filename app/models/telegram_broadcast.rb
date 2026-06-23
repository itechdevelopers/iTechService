class TelegramBroadcast < ApplicationRecord
  belongs_to :telegram_chat
  has_many :variants, class_name: 'TelegramBroadcastVariant',
                      dependent: :destroy, inverse_of: :broadcast
  accepts_nested_attributes_for :variants, allow_destroy: true,
                                           reject_if: ->(a) { a[:body].blank? }

  mount_uploader :image, TelegramBroadcastImageUploader

  enum schedule_type: { day_of_month: 0, every_n_days: 1 }
  enum selection_mode: { random_variant: 0, in_order: 1 }

  scope :enabled, -> { where(active: true) }

  validates :title, presence: true
  validates :day_of_month, presence: true, inclusion: { in: 1..28 }, if: :day_of_month?
  validates :interval_days, presence: true,
                            numericality: { only_integer: true, greater_than_or_equal_to: 1 },
                            if: :every_n_days?
  validates :send_hour_from, :send_hour_to,
            inclusion: { in: 0..23 }, allow_nil: true
  validate :send_hours_consistent

  # Запускается тикером раз в час: отправляет все рассылки, которым «пора» сейчас.
  def self.deliver_due!(now = Time.current)
    enabled.includes(:telegram_chat, :variants).select { |b| b.due?(now) }.each do |broadcast|
      broadcast.deliver!(now)
    end
  end

  # Пора ли отправлять в этот час. Дедуп — last_sent_at (в этом часу уже слали?).
  # last_sent_on == date означает «день уже активирован» → продолжаем по часам окна.
  def due?(now = Time.current)
    return false unless active?
    return false if variants.empty?
    return false unless now.hour.between?(effective_hour_from, effective_hour_to)
    return false unless last_sent_at.nil? || last_sent_at < now.beginning_of_hour

    date = now.to_date
    last_sent_on == date ? true : day_due?(date)
  end

  # Окно отправки. Пустые поля → дефолт 09:00 (как до индивидуального часа).
  def effective_hour_from
    send_hour_from || 9
  end

  def effective_hour_to
    send_hour_to || send_hour_from || 9
  end

  # Выбирает один вариант (random / по кругу), шлёт в группу, двигает курсор.
  # last_sent_on/курсор обновляются ТОЛЬКО при успешной отправке.
  def deliver!(now = Time.current)
    variant, next_index = pick_variant
    return false if variant.nil?
    return false unless send_to_telegram(variant)

    update_columns(last_sent_on: now.to_date, last_sent_at: now, last_variant_index: next_index)
    true
  end

  # Тест-отправка из админки: реально шлёт в группу тот вариант, что ушёл бы
  # следующим, но НЕ трогает last_sent_on/курсор — на расписание не влияет,
  # кнопку можно жать многократно. Возвращает true/false по факту отправки.
  def deliver_now!
    variant, _next_index = pick_variant
    return false if variant.nil?

    send_to_telegram(variant)
  end

  private

  # Подходит ли день по расписанию (без учёта часа/внутрисуточных повторов).
  def day_due?(date)
    if day_of_month?
      date.day == day_of_month
    elsif every_n_days?
      last_sent_on.nil? || (date - last_sent_on).to_i >= interval_days
    else
      false
    end
  end

  # Окно «с/по»: конец не раньше начала. Один час задаётся from == to (или только from).
  def send_hours_consistent
    return if send_hour_from.nil? || send_hour_to.nil?
    return if send_hour_to >= send_hour_from

    errors.add(:send_hour_to, :greater_than_or_equal_to, count: send_hour_from)
  end

  # → [variant, next_index]. Для пустого набора — [nil, last_variant_index].
  def pick_variant
    ordered = variants.order(:id).to_a
    return [nil, last_variant_index] if ordered.empty?

    if random_variant?
      [ordered.sample, last_variant_index]
    else
      index = last_variant_index.to_i % ordered.size
      [ordered[index], (index + 1) % ordered.size]
    end
  end

  def send_to_telegram(variant)
    if image.present?
      SendTelegramSchedule.call(
        chat_id: telegram_chat.chat_id,
        image_data: Base64.encode64(image.read),
        caption: variant.body
      ).success?
    else
      SendTelegramMessage.call(
        chat_id: telegram_chat.chat_id,
        text: variant.body
      ).success?
    end
  end
end
