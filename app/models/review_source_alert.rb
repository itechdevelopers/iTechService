# frozen_string_literal: true

# Авария сбора отзывов: парсер-агент сутки не может получить отзывы с площадки
# и сообщает об этом через ReviewAgentApi.
#
# Отдельная сущность, а не поле в GisReview: у аварии свой жизненный цикл
# (открыта → закрыта восстановлением), своя единица учёта (площадка + филиал,
# а не конкретный отзыв) и свои получатели уведомлений.
class ReviewSourceAlert < ApplicationRecord
  belongs_to :department, optional: true
  # Иначе закрытие аварии оставило бы в колокольчике ссылку в никуда, если
  # запись когда-нибудь удалят.
  has_many :notifications, as: :referenceable, dependent: :destroy

  # Площадки те же, что у отзывов: доска состояния и бейджи отзывов должны
  # показывать один и тот же справочник.
  SOURCES = GisReview::SOURCES
  SOURCE_LABELS = GisReview::SOURCE_LABELS

  ALERT_TYPES = %w[source_unavailable source_recovered].freeze

  # Авария площадки целиком. Пустая строка, а не nil: в уникальном индексе
  # два NULL не конфликтуют, и глобальные аварии задвоились бы.
  GLOBAL_BRANCH_CODE = ''

  scope :unresolved, -> { where(resolved_at: nil) }
  scope :resolved,   -> { where.not(resolved_at: nil) }
  scope :recent,     -> { order(first_failed_at: :desc) }

  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :alert_type, presence: true, inclusion: { in: ALERT_TYPES }
  # Уникальность действует только среди ОТКРЫТЫХ аварий: ключ аварии у агента
  # стабилен во времени, и рецидив обязан завести новую запись — иначе он молча
  # обновит закрытую и никого не уведомит.
  validates :branch_code,
            uniqueness: { scope: :source, conditions: -> { where(resolved_at: nil) } },
            if: :unresolved?

  # Пустой branch_code от агента (глобальная авария) приходит как null или как
  # отсутствующее поле — приводим к одному виду на входе.
  def self.normalize_branch_code(branch_code)
    branch_code.presence || GLOBAL_BRANCH_CODE
  end

  # Открывает аварию либо обновляет уже открытую. Возвращает [запись, признак
  # первого появления] — уведомление шлём только на первое.
  def self.open_or_update(attributes)
    source = attributes.fetch(:source)
    branch_code = normalize_branch_code(attributes[:branch_code])
    alert = unresolved.find_by(source: source, branch_code: branch_code)
    first_appearance = alert.nil?
    alert ||= new(source: source, branch_code: branch_code)

    alert.assign_attributes(attributes.except(:source, :branch_code, :first_failed_at))
    # Начало аварии не перезаписываем: агент держит health-state в локальных
    # файлах, и после его перезапуска отсчёт пойдёт заново — «авария 50 часов»
    # на глазах превратилась бы в «авария 2 часа».
    alert.first_failed_at ||= attributes[:first_failed_at]
    alert.save!

    [alert, first_appearance]
  end

  # Закрывает аварии по восстановлению. Возвращает закрытые записи; пустой
  # массив — восстановление пришло в пустоту (Айс подняли уже после аварии,
  # либо её закрыли руками), это не ошибка.
  def self.resolve(source:, branch_code: nil, message: nil)
    code = normalize_branch_code(branch_code)
    scope = unresolved.where(source: source)
    # Восстановление площадки целиком закрывает и филиальные аварии: «2ГИС
    # снова работает» означает, что лежащих филиалов не осталось. Закрывай мы
    # строго по паре — филиальные записи не закрыл бы уже никто (агент их
    # больше не пришлёт), и суточная сводка вечно звенела бы про мёртвую
    # аварию. Если филиал на самом деле ещё лежит, агент откроет его заново.
    scope = scope.where(branch_code: code) unless code == GLOBAL_BRANCH_CODE

    scope.to_a.each do |alert|
      alert.update!(resolved_at: Time.zone.now, resolved_message: message)
    end
  end

  # Подразделение по коду филиала — тот же резолв, что у отзывов: коды агента
  # совпадают с departments.code и одинаковы у всех площадок.
  def self.department_for(branch_code)
    GisReview.department_for(branch_code)
  end

  # Сводка по всем открытым авариям одним сообщением. nil — открытых нет, и
  # тогда никто ничего не шлёт: тишина здесь и означает «всё работает».
  def self.digest_telegram_text
    alerts = unresolved.includes(:department).to_a
    return nil if alerts.empty?

    lines = alerts.sort_by { |alert| -(alert.duration_hours || 0) }
                  .map { |alert| CGI.escapeHTML("#{alert.full_label}: #{alert.duration_label}") }

    [
      "<b>Сбор отзывов: открытых аварий #{alerts.size}</b>",
      lines.join("\n"),
      %(<a href="#{alerts.first.index_url}">Открыть состояние источников</a>)
    ].join("\n\n")
  end

  def unresolved?
    resolved_at.nil?
  end

  def resolved?
    !unresolved?
  end

  def global?
    branch_code.blank?
  end

  # Уведомляем только суперадминов и только при первом появлении аварии:
  # агент шлёт её на каждом прогоне, пока она держится.
  def notify_about_opening
    User.superadmins.active.each do |recipient|
      notification = Notification.create!(
        user: recipient,
        message: notification_message,
        url: index_path,
        referenceable: self
      )
      UserNotificationChannel.broadcast_to(recipient, notification)
      NotifyEmployeeJob.perform_later(recipient.id, telegram_text)
    end
  end

  def notification_message
    "Сбор отзывов не работает: #{full_label} (#{duration_label}). #{message}".strip
  end

  # parse_mode HTML — текст ошибки от агента приходит с < и > (имена классов
  # исключений, куски URL), без экранирования Телеграм отбивает сообщение.
  def telegram_text
    [
      "<b>Сбор отзывов не работает: #{CGI.escapeHTML(full_label)}</b>",
      CGI.escapeHTML("Не восстанавливается #{duration_label}."),
      CGI.escapeHTML([message, last_error].reject(&:blank?).join("\n")),
      %(<a href="#{index_url}">Открыть состояние источников</a>)
    ].reject(&:blank?).join("\n\n")
  end

  # «2ГИС — вся площадка» или «Яндекс — Некрасовская 64, Уссурийск».
  def full_label
    [source_label, branch_label].join(' — ')
  end

  def source_label
    SOURCE_LABELS.fetch(source, source)
  end

  # Название филиала берём из справочника подразделений, а не из payload:
  # агент шлёт его не всегда. Голый код филиала — последний фолбэк, чтобы
  # строка не осталась пустой.
  def branch_label
    return 'вся площадка' if global?

    department&.name.presence || branch_name.presence || branch_code
  end

  # Длительность считаем сами, от начала аварии до «сейчас». hours_failed от
  # агента — его оценка на момент последней проверки: если агент замолчит,
  # она застынет и будет показывать «24 часа» третьи сутки.
  def duration_hours
    return nil if first_failed_at.blank?

    ((resolved_at || Time.zone.now) - first_failed_at) / 1.hour
  end

  def duration_label
    hours = duration_hours
    return 'длительность неизвестна' if hours.blank?

    hours < 24 ? "#{hours.round} ч" : "#{(hours / 24).floor} сут #{(hours % 24).round} ч"
  end

  def index_path
    Rails.application.routes.url_helpers.review_source_alerts_path
  end

  # Абсолютная ссылка для Телеграма: в dev у routes нет default_url_options,
  # и _url-хелпер падает с «Missing host to link to».
  def index_url
    Rails.application.routes.url_helpers.review_source_alerts_url(host: app_host)
  end

  def app_host
    ENV['SERVER_HOST'].presence ||
      Rails.application.routes.default_url_options[:host].presence ||
      'localhost:3000'
  end
end
