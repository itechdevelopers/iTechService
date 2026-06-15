class BirthdayGreeting < ApplicationRecord
  MAX_VARIANTS = 20

  belongs_to :telegram_chat, optional: true

  has_many :variants, class_name: 'BirthdayGreetingVariant',
                      dependent: :destroy, inverse_of: :greeting
  has_many :gifs, class_name: 'BirthdayGreetingGif',
                  dependent: :destroy, inverse_of: :greeting

  accepts_nested_attributes_for :variants, allow_destroy: true,
                                           reject_if: ->(a) { a[:body].blank? }
  accepts_nested_attributes_for :gifs, allow_destroy: true,
                                       reject_if: ->(a) { a[:file].blank? }

  validate :variants_count_within_limit

  # Синглтон: одна строка-настройка на всю систему.
  def self.instance
    first_or_create!
  end

  # Запускается тикером раз в сутки в 10:00 ВЛД: поздравляет всех, у кого сегодня ДР.
  # Защита от повторной отправки за день — last_run_on (ретраи Sidekiq / ручной перезапуск).
  def self.deliver_today!(date = Date.current)
    instance.deliver_today!(date)
  end

  # Каждому имениннику — отдельное сообщение со своим случайным вариантом и (опц.) гифкой.
  # last_run_on обновляется ТОЛЬКО при общем успехе прохода (нет токена/чата → не двигаем).
  def deliver_today!(date = Date.current)
    return false unless deliverable?
    return false if last_run_on == date

    celebrants = User.active.select { |user| user.birthday_today?(date) }
    return false if celebrants.empty?

    celebrants.each { |user| deliver_for(user) }
    update_columns(last_run_on: date)
    true
  end

  # Тест-отправка из админки: шлёт поздравления сегодняшним именинникам прямо сейчас,
  # но НЕ трогает last_run_on — на расписание не влияет, кнопку можно жать многократно.
  # Возвращает число обработанных именинников.
  def deliver_now!(date = Date.current)
    return 0 unless variants.any?

    celebrants = User.active.select { |user| user.birthday_today?(date) }
    celebrants.each { |user| deliver_for(user) }
    celebrants.size
  end

  private

  # Настройка боеспособна: включена, есть чат и хотя бы один вариант.
  def deliverable?
    enabled? && telegram_chat.present? && variants.any?
  end

  # Сборка сообщения на лету: @ник Имя Фамилия (Подразделение) <случайный вариант>.
  def deliver_for(user)
    text = build_message(user)
    gif = pick_gif

    if gif
      SendTelegramAnimation.call(
        chat_id: telegram_chat.chat_id,
        file_path: gif.file.path,
        caption: text
      ).success?
    else
      SendTelegramMessage.call(chat_id: telegram_chat.chat_id, text: text).success?
    end
  rescue StandardError => e
    # Падение по одному имениннику не должно ронять остальных.
    Rails.logger.error("[BirthdayGreeting] deliver_for(user=#{user.id}) failed: #{e.message}")
    false
  end

  def build_message(user)
    mention = "@#{user.telegram_username}" if user.telegram_username.present?
    department = "(#{user.department_name})" if user.department_name.present?
    [mention, user.short_name, department, variants.sample.body].compact.join(' ')
  end

  # Случайная гифка из набора, если включено и есть загруженные. Иначе nil → текст.
  def pick_gif
    return nil unless send_gif?

    gifs.sample
  end

  def variants_count_within_limit
    if variants.reject(&:marked_for_destruction?).size > MAX_VARIANTS
      errors.add(:base, "Максимум #{MAX_VARIANTS} вариантов поздравлений")
    end
  end
end
