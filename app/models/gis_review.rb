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
end
