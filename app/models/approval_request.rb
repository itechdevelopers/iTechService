# frozen_string_literal: true

# Запрос технаря на согласование чего-либо с клиентом (стоимость, сроки, объём
# работ). Рождается вместе с паузой «Ждём согласования», отвечают сотрудники
# локации «Медиа», после ответа технарь сам снимает ремонт с паузы.
#
# По одной работе может висеть НЕСКОЛЬКО неотвеченных запросов сразу: техник
# нередко спрашивает клиента и про плату, и про экран, не дожидаясь ответа на
# первое (решение заказчика 2026-08-20). Медиа отвечает на каждый отдельно.
class ApprovalRequest < ApplicationRecord
  belongs_to :service_job
  belongs_to :requester, class_name: 'User', optional: true
  belongs_to :responder, class_name: 'User', optional: true

  enum status: {
    pending:  'pending',
    approved: 'approved',
    rejected: 'rejected'
  }

  validates :question, presence: true

  scope :chronological, -> { order(:created_at) }
  scope :recent_first,  -> { order(created_at: :desc) }
  scope :answered,      -> { where(status: %w[approved rejected]) }
  # Запросы по ремонтам указанного подразделения: медиа отвечает за свой отдел,
  # витрина «С согласования» у технарей фильтруется так же.
  scope :in_department, lambda { |department|
    joins(:service_job).where(service_jobs: { department_id: department })
  }
  # «Требуют действия технаря»: ответ получен, а ремонт всё ещё стоит на паузе
  # «Ждём согласования» — значит про запрос забыли. Тот же scope питает и
  # подсветку строки, и цифру бейджа: иначе они разойдутся.
  scope :awaiting_resume_in, lambda { |department|
    answered
      .joins(service_job: %i[repair_status repair_pause_reason])
      .where(repair_statuses: { code: RepairStatus::PAUSED })
      .where(repair_pause_reasons: { code: RepairPauseReason::WAITING_APPROVAL })
      .where(service_jobs: { department_id: department })
  }

  # Ответ медиа. Идемпотентно: повторный сабмит по уже отвеченному запросу
  # ничего не меняет и возвращает false — вызывающий не шлёт дубль уведомления.
  def answer!(outcome:, comment:, user:)
    outcome = outcome.to_s
    return false unless pending? && %w[approved rejected].include?(outcome)

    update(status: outcome, response_comment: comment.presence,
           responder: user, responded_at: Time.current)
  end

  # Сколько заняло согласование, в секундах (nil, пока нет ответа).
  def duration
    return nil unless responded_at

    responded_at - created_at
  end

end
