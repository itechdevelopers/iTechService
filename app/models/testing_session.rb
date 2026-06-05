# frozen_string_literal: true

class TestingSession < ApplicationRecord
  belongs_to :service_job
  belongs_to :sender,          class_name: 'User',     optional: true
  belongs_to :target_location, class_name: 'Location', optional: true
  belongs_to :tester,          class_name: 'User',     optional: true

  enum status: {
    not_started: 'not_started',
    in_progress: 'in_progress',
    passed:      'passed',
    failed:      'failed'
  }

  FAILURE_ACTIONS = {
    return_to_tech: 'return_to_tech',
    retry:          'retry'
  }.freeze

  validates :status, presence: true
  validates :failure_action, inclusion: { in: FAILURE_ACTIONS.values }, allow_nil: true

  scope :chronological, -> { order(:created_at) }
  scope :finished,      -> { where(status: %w[passed failed]) }
  # Активные = ещё не завершённые: видны входящими у целевого отдела.
  scope :active,        -> { where(status: %w[not_started in_progress]) }
  # Вернувшиеся к технарю: прошедшие ИЛИ проваленные с возвратом
  # (retry исключаем — устройство снова ушло на тест, не вернулось).
  scope :returned, lambda {
    where(status: 'passed')
      .or(where(status: 'failed', failure_action: FAILURE_ACTIONS[:return_to_tech]))
  }
  # Сессии, чей ремонт «живёт» в указанном подразделении (по department_id
  # самого service_job). Витрина «Вернулось» фильтруется по отделу сотрудника,
  # а не по sender — вернувшееся видит весь ремонтный отдел, не только отправитель.
  scope :in_department, lambda { |department|
    joins(:service_job).where(service_jobs: { department_id: department })
  }
  # Сессии, доступные сотруднику как тестировщику: ограничены его локацией
  # (target_location). У админов без локации — все. Единый источник и для
  # витрины /testings (что видно/подсвечено), и для счётчика-бейджа в навбаре,
  # чтобы цифра бейджа всегда совпадала с числом строк на странице.
  scope :for_tester, lambda { |user|
    user&.location_id.present? ? where(target_location_id: user.location_id) : all
  }

  # Длительность теста в секундах (nil, пока тест не завершён).
  def duration
    return nil unless started_at && ended_at
    ended_at - started_at
  end

  # Старт теста сотрудником. Защита от гонки: обновляем только если запись
  # ещё в not_started (двое не перетрут tester друг друга — побеждает первый).
  # Возвращает true, если именно этот вызов перевёл сессию в in_progress.
  def start_by!(user)
    updated = self.class.not_started.where(id: id).update_all(
      status: 'in_progress', tester_id: user.id,
      started_at: Time.current, updated_at: Time.current
    )
    reload
    updated.positive?
  end

  # Завершение теста: in_progress → passed/failed, фиксируем ended_at + заметки.
  # При failed сохраняем failure_action (return_to_tech / retry); при retry
  # создаём НОВУЮ сессию (история попыток) — копия маршрута, статус not_started.
  # Возвращает новую retry-сессию или nil. Всё в одной транзакции.
  def finish!(outcome:, notes:, failure_action: nil)
    outcome = outcome.to_s
    return nil unless in_progress? && %w[passed failed].include?(outcome)

    action = outcome == 'failed' ? failure_action.to_s.presence_in(FAILURE_ACTIONS.values) : nil
    retry_session = nil
    transaction do
      update!(status: outcome, notes: notes, ended_at: Time.current, failure_action: action)
      retry_session = build_retry_session.tap(&:save!) if action == FAILURE_ACTIONS[:retry]
    end
    retry_session
  end

  private

  def build_retry_session
    self.class.new(
      service_job: service_job, sender: sender,
      target_location: target_location, what_to_test: what_to_test,
      status: 'not_started'
    )
  end
end
