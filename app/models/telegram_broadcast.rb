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

  # Запускается тикером раз в сутки: отправляет все рассылки, которым «пора».
  def self.deliver_due!(date = Date.current)
    enabled.includes(:telegram_chat, :variants).select { |b| b.due?(date) }.each do |broadcast|
      broadcast.deliver!(date)
    end
  end

  # Пора ли отправлять сегодня. Защита от повторной отправки в тот же день — last_sent_on.
  def due?(date = Date.current)
    return false unless active?
    return false if variants.empty?
    return false if last_sent_on == date

    if day_of_month?
      date.day == day_of_month
    elsif every_n_days?
      last_sent_on.nil? || (date - last_sent_on).to_i >= interval_days
    else
      false
    end
  end

  # Выбирает один вариант (random / по кругу), шлёт в группу, двигает курсор.
  # last_sent_on/курсор обновляются ТОЛЬКО при успешной отправке.
  def deliver!(date = Date.current)
    ordered = variants.order(:id).to_a
    return false if ordered.empty?

    if random_variant?
      variant    = ordered.sample
      next_index = last_variant_index
    else
      index      = last_variant_index.to_i % ordered.size
      variant    = ordered[index]
      next_index = (index + 1) % ordered.size
    end

    return false unless send_to_telegram(variant)

    update_columns(last_sent_on: date, last_variant_index: next_index)
    true
  end

  private

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
