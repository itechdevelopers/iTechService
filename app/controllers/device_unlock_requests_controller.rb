# frozen_string_literal: true

class DeviceUnlockRequestsController < ApplicationController
  # Приоритет-сортировка по статусам (Цикл 6). Чипы-тогглы передают
  # ?priority[]=<status_key>; отмеченные статусы всплывают наверх, остальные
  # остаются ниже (это сортировка, НЕ фильтр-отсев). Валидируем ключи по
  # statuses.keys → в SQL уходят только integer-коды из enum, инъекция исключена.
  def index
    authorize DeviceUnlockRequest

    @priority_statuses =
      Array(params[:priority]).select { |s| DeviceUnlockRequest.statuses.key?(s) }
    @status_counts = status_counts

    scope = DeviceUnlockRequest.recent.includes(:client, :item, :comments)
    if @priority_statuses.any?
      codes = @priority_statuses.map { |s| DeviceUnlockRequest.statuses[s] }
      # reorder (не order): перебиваем created_at из scope `recent` ведущим
      # CASE-ключом, created_at DESC оставляем вторым — стабильный порядок внутри групп.
      scope = scope.reorder(
        Arel.sql("CASE WHEN status IN (#{codes.join(',')}) THEN 0 ELSE 1 END"),
        created_at: :desc
      )
    end

    @device_unlock_requests = scope
  end

  def show
    @device_unlock_request = find_record DeviceUnlockRequest
  end

  def new
    @device_unlock_request = authorize DeviceUnlockRequest.new
  end

  def create
    @device_unlock_request = authorize DeviceUnlockRequest.new(device_unlock_request_params)
    # Автор и департамент — на сервере (как в приёмке / client_requests#create).
    # status берёт дефолт из БД (0 = new_request, см. миграцию).
    @device_unlock_request.user = current_user
    @device_unlock_request.department = current_user.department

    if @device_unlock_request.save
      redirect_to device_unlock_requests_path, notice: t('.created')
    else
      render :new
    end
  end

  # Смена workflow-статуса кнопкой-ссылкой remote:true. find_record авторизует
  # через update_status? (action_name → одноимённый предикат policy).
  def update_status
    @device_unlock_request = find_record DeviceUnlockRequest

    if @device_unlock_request.update(status_params)
      respond_to do |format|
        format.js   # перерисовывает строку #device_unlock_request_<id>
        format.html { redirect_to device_unlock_requests_path, notice: t('.updated') }
      end
    else
      head :unprocessable_entity
    end
  end

  # Инлайн-добавление комментария прямо из строки таблицы (Цикл 4). НЕ через
  # CommentsController: создаём Comment и перерисовываем строку (паттерн
  # update_status), чтобы новый «последний комментарий» сразу появился в ячейке.
  def add_comment
    @device_unlock_request = find_record DeviceUnlockRequest
    comment = @device_unlock_request.comments.build(content: params[:content], user: current_user)

    if comment.save
      respond_to do |format|
        format.js   # add_comment.js.erb — replaceWith строки
        format.html { redirect_to device_unlock_requests_path }
      end
    else
      head :unprocessable_entity # пустой комментарий — молча, без перерисовки
    end
  end

  # Часики в колонке комментариев — модалка со ВСЕМИ комментариями запроса
  # (в таблице видно только последний). Переиспользуем общую модалку:
  # shared/show_modal_form рендерит партиал из params[:form_name] → _comments_modal.
  def comments
    @device_unlock_request = find_record DeviceUnlockRequest
    render 'shared/show_modal_form'
  end

  # История изменений (иконка часов) — читает HistoryRecord, как в clients#history.
  def history
    @device_unlock_request = find_record DeviceUnlockRequest
    @records = @device_unlock_request.history_records.order(created_at: :desc)
    render 'shared/show_history'
  end

  private

  # Счётчики для бейджей на чипах. group(:status).count в Rails 5.1 может вернуть
  # ключами либо integer-коды, либо строковые имена — нормализуем к именам enum,
  # чтобы во вью обращаться по строковому ключу статуса.
  def status_counts
    DeviceUnlockRequest.group(:status).count.each_with_object(Hash.new(0)) do |(key, count), acc|
      name = key.is_a?(Integer) ? DeviceUnlockRequest.statuses.key(key) : key.to_s
      acc[name] = count
    end
  end

  def device_unlock_request_params
    params.require(:device_unlock_request).permit(:client_id, :item_id, :reason)
  end

  def status_params
    params.require(:device_unlock_request).permit(:status)
  end
end
