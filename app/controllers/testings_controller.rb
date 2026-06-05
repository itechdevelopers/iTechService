# frozen_string_literal: true

# Витрина входящих на тестирование устройств для сотрудников целевого отдела.
# Видимость и право старта — по локации сотрудника (current_user.location).
class TestingsController < ApplicationController
  def index
    authorize :testing, :index?

    @testing_sessions = accessible_sessions.active
                          .includes(:sender, :tester, :target_location, service_job: :client)
                          .chronological
  end

  # «ВЕРНУЛОСЬ С ТЕСТИРОВАНИЯ»: завершённые сессии (прошедшие ИЛИ возвращённые
  # после провала; retry — нет), чей ремонт живёт в подразделении сотрудника.
  # Видимость по отделу, а не по sender — вернувшееся видит весь ремонтный отдел.
  def returned
    authorize :testing, :returned?

    @testing_sessions = TestingSession.returned
                          .in_department(current_department)
                          .includes(:tester, :target_location, service_job: :client)
                          .order(ended_at: :desc)
  end

  # Старт теста: not_started → in_progress, фиксируем tester + started_at.
  # accessible_sessions ограничивает выбор локацией сотрудника (чужую → 404).
  def start
    authorize :testing, :start?
    @testing_session = accessible_sessions.find(params[:id])
    @testing_session.start_by!(current_user)

    respond_to { |format| format.js }
  end

  # Открывает модалку завершения теста (исход — passed/failed из params).
  def finish_prompt
    authorize :testing, :finish?
    @testing_session = accessible_sessions.find(params[:id])
    @outcome = params[:outcome].to_s.presence_in(%w[passed failed]) || 'passed'

    respond_to { |format| format.js }
  end

  # Завершение теста. На retry модель возвращает новую сессию → вставляем строку.
  def finish
    authorize :testing, :finish?
    @testing_session = accessible_sessions.find(params[:id])
    # Запоминаем ДО finish!: уведомляем только если именно этот вызов завершил
    # тест (был in_progress → стал passed/failed). Иначе повторный сабмит по уже
    # завершённой сессии (finish! no-op) слал бы дубль уведомления.
    was_in_progress = @testing_session.in_progress?
    @retry_session = @testing_session.finish!(
      outcome: params[:outcome],
      notes: params[:notes],
      failure_action: params[:failure_action]
    )

    if was_in_progress && (@testing_session.passed? || @testing_session.failed?)
      SendTestingTelegramNotificationJob.perform_later(@testing_session.id)
      SendTestingInAppNotificationJob.perform_later(@testing_session.id)
    end

    respond_to { |format| format.js }
  end

  # Снятие ремонта с «тестовой» паузы после неудачного теста: paused → in_progress.
  # Отсчёт времени ремонта (return_at) возобновляется. Идемпотентно: если ремонт
  # уже снят с паузы — ничего не делаем (не плодим записи в repair_status_changes).
  def resume
    authorize :testing, :resume?
    # scope-then-find: ограничиваем отделом сотрудника (как и список «Вернулось»),
    # чужой отдел → RecordNotFound (404). Защита от IDOR на уровне записи, т.к.
    # headless TestingPolicy конкретную запись не проверяет.
    @testing_session = TestingSession.in_department(current_department).find(params[:id])
    service_job = @testing_session.service_job

    if service_job.repair_status&.paused?
      service_job.change_repair_status!(RepairStatus.by_code(RepairStatus::IN_PROGRESS), user: current_user)
      @testing_session.reload # сбросить устаревший после update_columns кэш repair_status
    end

    respond_to { |format| format.js }
  end

  private

  # Сессии, доступные текущему сотруднику: его локация (у админов без
  # локации — все). Используется и для списка, и для проверки прав на старт.
  # Тот же scope питает счётчик-бейдж в навбаре (см. dashboard/index) — выборка
  # подсветки и цифры бейджа намеренно одна.
  def accessible_sessions
    TestingSession.for_tester(current_user)
  end
end
