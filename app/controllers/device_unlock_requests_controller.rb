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

    # Архивные (Цикл 8) в основной таблице не показываем — только .active.
    scope = DeviceUnlockRequest.active.recent.includes(:client, :item, :comments)
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
      # Событийное in-app уведомление суперадминам о новом запросе (план §6).
      # Синхронно, без джобы — как GlassStickingController#notify.
      @device_unlock_request.notify_about_creation
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
      # Авто-уведомление суперадминам при переходе в «Согласован»/«Отказ клиента»
      # (план §11, Цикл 10). needs_approval пойдёт через пикер (Циклы 11–12).
      if %w[approved client_declined].include?(@device_unlock_request.status)
        @device_unlock_request.notify_superadmins_of_status
      end

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

  # Пикер получателей при переходе в «Требует согласования» (план §11, Цикл 11).
  # Кнопка «На согласование» открывает эту модалку — статус здесь НЕ меняем
  # (гейт, реш. §11.5): перевод делает notify_approval. Список — сотрудники
  # ТОГО ЖЕ департамента, что и запрос, сгруппируем по локациям во вью (Цикл 12).
  def approval_picker
    @device_unlock_request = find_record DeviceUnlockRequest
    @available_users = approval_recipients_scope
    # Переиспользуем общую модалку: show_modal_form рендерит партиал из
    # params[:form_name] → _approval_recipients_modal (контейнер #modal_form
    # создаётся на лету, если его ещё нет). Паттерн модалки комментариев (Цикл 5).
    render 'shared/show_modal_form'
  end

  # Submit пикера: и переводит статус в needs_approval, и рассылает уведомления
  # выбранным. Перевод статуса — ЗДЕСЬ, а не в update_status (гейт §11.5): клик
  # по кнопке сам по себе статус не трогает, только этот submit. Пустой user_ids =
  # «перевести без уведомления» → статус меняем, рассылки нет.
  def notify_approval
    @device_unlock_request = find_record DeviceUnlockRequest
    @device_unlock_request.update(status: :needs_approval)

    # Валидация скоупа: пересекаем присланные id с сотрудниками департамента
    # запроса — защита от подмены id из чужого департамента (ср. #index priority).
    ids = Array(params[:user_ids]).map(&:to_i) & approval_recipients_scope.ids
    @notified_count = ids.size # для inline-flash во вью (sent vs moved)
    if ids.any?
      recipients = User.where(id: ids)
      # Пикер — единственный сценарий, где автора-оператора исключаем: он
      # выбирает получателей руками и себя в списке видеть не должен (реш. 02.07).
      @device_unlock_request.notify(
        recipients,
        @device_unlock_request.status_notification_message,
        url: @device_unlock_request.show_url,
        exclude_current_user: true
      )
    end

    respond_to do |format|
      format.js   # notify_approval.js.erb — перерисовка строки + закрытие модалки (Цикл 12)
      format.html { redirect_to device_unlock_requests_path, notice: t('.moved') }
    end
  end

  # Часики в колонке комментариев — модалка со ВСЕМИ комментариями запроса
  # (в таблице видно только последний). Переиспользуем общую модалку:
  # shared/show_modal_form рендерит партиал из params[:form_name] → _comments_modal.
  def comments
    @device_unlock_request = find_record DeviceUnlockRequest
    render 'shared/show_modal_form'
  end

  # Архив (Цикл 8). «В архив» — PATCH с redirect (не remote): после archive!
  # redirect_to index → строка уходит из .active-списка (паттерн kanban).
  def archive
    @device_unlock_request = find_record DeviceUnlockRequest
    @device_unlock_request.archive!
    redirect_to device_unlock_requests_path, notice: t('.archived')
  end

  def unarchive
    @device_unlock_request = find_record DeviceUnlockRequest
    @device_unlock_request.unarchive!
    redirect_to archived_requests_device_unlock_requests_path, notice: t('.unarchived')
  end

  # Список архивных запросов (read-only): без кнопок смены статуса и инлайн-формы
  # комментария, единственное действие — «Разархивировать» (см. партиал).
  def archived_requests
    authorize DeviceUnlockRequest
    @device_unlock_requests =
      DeviceUnlockRequest.archived.recent.includes(:client, :item, :comments)
  end

  # История изменений (иконка часов) — читает HistoryRecord, как в clients#history.
  def history
    @device_unlock_request = find_record DeviceUnlockRequest
    @records = @device_unlock_request.history_records.order(created_at: :desc)
    render 'shared/show_history'
  end

  private

  # Кандидаты в получатели уведомления «на согласовании» (план §11.3/§11.4):
  # строго сотрудники департамента запроса, только действующие (.active — не
  # уволенные), в штатном порядке (.ordered). И группы-локации, и поиск отдельного
  # человека во вью работают внутри этого множества; на этом же множестве
  # валидируем params[:user_ids] в notify_approval.
  def approval_recipients_scope
    User.in_department(@device_unlock_request.department_id).active.ordered
  end

  # Счётчики для бейджей на чипах. group(:status).count в Rails 5.1 может вернуть
  # ключами либо integer-коды, либо строковые имена — нормализуем к именам enum,
  # чтобы во вью обращаться по строковому ключу статуса.
  def status_counts
    # Только активные — архивные не учитываем в счётчиках чипов.
    DeviceUnlockRequest.active.group(:status).count.each_with_object(Hash.new(0)) do |(key, count), acc|
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
