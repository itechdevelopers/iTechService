# frozen_string_literal: true

# Отзыв из 2ГИС, присланный парсер-агентом через ReviewAgentApi.
#
# ВНИМАНИЕ: не путать с моделью Review — там оценки клиентов по конкретному
# ремонту (belongs_to :service_job, право show_reviews). Здесь публичные отзывы
# из карточек филиалов, привязанные к сотруднику по имени в тексте.
class GisReview < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :city, optional: true
  belongs_to :assigned_by, class_name: 'User', optional: true

  has_many :comments, as: :commentable, dependent: :destroy

  audited

  # Позитивная ветка: assigned / need_assignment. Негативная (1–3★): три
  # состояния обработки. Коды стабильны — в БД уже лежат записи, менять нельзя.
  enum status: {
    assigned:             0,
    need_assignment:      1,
    negative_new:         2,
    negative_in_progress: 3,
    negative_resolved:    4
  }

  # Словарь статусов агента → наши. Агент шлёт одно значение `negative`, а в
  # Айсе у негатива свой воркфлоу, поэтому входной `negative` — это стартовая
  # точка negative_new, дальше статус двигают руками.
  AGENT_STATUSES = {
    'assigned'        => :assigned,
    'need_assignment' => :need_assignment,
    'negative'        => :negative_new
  }.freeze

  NEGATIVE_STATUSES = %w[negative_new negative_in_progress negative_resolved].freeze

  scope :negative, -> { where(status: NEGATIVE_STATUSES) }
  scope :recent,   -> { order(reviewed_at: :desc) }

  validates :external_review_id, presence: true, uniqueness: true
  validates :city_name, :reviewed_at, presence: true
  validates :rating, presence: true, inclusion: { in: 1..5 }

  def last_comment
    comments.newest.first
  end

  def negative?
    NEGATIVE_STATUSES.include?(status)
  end

  # Кандидаты на привязку: сотрудники локации «Бар» ВСЕХ филиалов города отзыва —
  # ровно то множество, которое агент получает через API и в котором ищет имя.
  # Если город не распознался, сужать не по чему — отдаём бар целиком.
  def employee_candidates
    locations = city_id.present? ? Location.bar.in_city(city_id) : Location.bar
    User.active.located_at(locations).order(:surname, :name)
  end

  # --- Уведомления о новом негативном отзыве (заказчик: «отправляем суперадминам
  # отзыв в айс и тг бот. Текст, филиал») ---
  # Зовётся из ReviewAgentApi только при СОЗДАНИИ негативного отзыва: агент
  # пере-присылает отзывы месяца на каждом прогоне, и без этого гейта суперадмины
  # получали бы одно и то же уведомление круглые сутки.
  def notify_about_creation
    User.superadmins.active.each do |recipient|
      notification = Notification.create!(
        user: recipient,
        message: creation_notification_message,
        url: index_path,
        referenceable: self
      )
      UserNotificationChannel.broadcast_to(recipient, notification)
      NotifyEmployeeJob.perform_later(recipient.id, telegram_text)
    end
  end

  def creation_notification_message
    "Новый негативный отзыв 2ГИС (#{rating}★), #{branch_label}: #{text}"
  end

  # HTML-разметка: SendTelegramMessage шлёт с parse_mode HTML, поэтому текст
  # отзыва и название филиала экранируем — в них бывают <, > и &.
  def telegram_text
    [
      "<b>Новый негативный отзыв 2ГИС (#{rating}★)</b>",
      CGI.escapeHTML(branch_label),
      CGI.escapeHTML(text.to_s),
      %(<a href="#{index_url}">Открыть негативные отзывы</a>)
    ].join("\n\n")
  end

  # Город + филиал: филиал агент шлёт не всегда, город есть всегда.
  def branch_label
    [city_name, branch_name].reject(&:blank?).join(', ')
  end

  def index_path
    Rails.application.routes.url_helpers.gis_reviews_path
  end

  # Абсолютная ссылка для Телеграма. Хост берём с тем же фолбэком, что и
  # reception_photo_check_job: в dev routes.default_url_options не задан, и
  # обычный _url-хелпер там падает с «Missing host to link to».
  def index_url
    Rails.application.routes.url_helpers.gis_reviews_url(host: app_host)
  end

  def app_host
    ENV['SERVER_HOST'].presence ||
      Rails.application.routes.default_url_options[:host].presence ||
      'localhost:3000'
  end
end
