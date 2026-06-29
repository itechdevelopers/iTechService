# frozen_string_literal: true

class ClientRequestsController < ApplicationController
  # Приоритет-сортировка по статусам (Цикл 6). Чипы-тогглы передают
  # ?priority[]=<status_key>; отмеченные статусы всплывают наверх, остальные
  # остаются ниже (сортировка, НЕ фильтр-отсев). Ключи валидируем по
  # statuses.keys → в SQL уходят только integer-коды из enum, инъекция исключена.
  def index
    authorize ClientRequest

    @priority_statuses =
      Array(params[:priority]).select { |s| ClientRequest.statuses.key?(s) }
    @status_counts = status_counts

    # Архивные (Цикл 7) в основной таблице не показываем — только .active.
    scope = ClientRequest.active.recent.includes(:client, :item)
    if @priority_statuses.any?
      codes = @priority_statuses.map { |s| ClientRequest.statuses[s] }
      # reorder (не order): перебиваем created_at из scope `recent` ведущим
      # CASE-ключом, created_at DESC оставляем вторым — стабильный порядок внутри групп.
      scope = scope.reorder(
        Arel.sql("CASE WHEN status IN (#{codes.join(',')}) THEN 0 ELSE 1 END"),
        created_at: :desc
      )
    end

    @client_requests = scope
  end

  def show
    @client_request = find_record ClientRequest
  end

  def new
    @client_request = authorize ClientRequest.new
  end

  def create
    @client_request = authorize ClientRequest.new(client_request_params)
    # Автор и департамент — на сервере (как в приёмке, service_jobs#create).
    # kind/status/purchase_check_status берут дефолты из БД: 0/0/0 =
    # receipt_search / new_request / pending (см. миграцию create_client_requests).
    @client_request.user = current_user
    @client_request.department = current_user.department

    if @client_request.save
      redirect_to client_requests_path, notice: t('.created')
    else
      render :new
    end
  end

  # Полное редактирование запроса — ТОЛЬКО superadmin (find_record авторизует
  # через edit?/update?). Позволяет исправить устройство (ошибочный серийник),
  # комментарий и вручную проставить дату покупки.
  def edit
    @client_request = find_record ClientRequest
  end

  def update
    @client_request = find_record ClientRequest
    attrs = client_request_edit_params
    attrs[:sold_at] = parse_sold_at(attrs[:sold_at])
    @client_request.assign_attributes(attrs)

    item_changed = @client_request.item_id_changed?
    # Ручной ввод даты покупки = подтверждаем покупку вручную (раз 1С не смогла).
    @client_request.purchase_check_status = :confirmed if @client_request.sold_at.present?

    if @client_request.save
      # Сменили устройство, а дату руками не задали → перепроверить покупку в 1С
      # с новым серийником (см. after_commit на create — здесь дёргаем явно).
      CheckClientRequestPurchaseJob.perform_later(@client_request.id) if item_changed && @client_request.sold_at.blank?
      redirect_to client_requests_path, notice: t('.updated')
    else
      render :edit
    end
  end

  # Смена workflow-статуса (в работу / выполнен / не выполнен) — кнопка-ссылка
  # remote:true. find_record авторизует через update_status? (action_name → предикат policy).
  def update_status
    @client_request = find_record ClientRequest

    if @client_request.update(status_params)
      respond_to do |format|
        format.js   # перерисовывает строку #client_request_<id>
        format.html { redirect_to client_requests_path, notice: t('.updated') }
      end
    else
      head :unprocessable_entity
    end
  end

  # Архив (Цикл 7). Кнопка «В архив» — PATCH с redirect (не remote): после
  # archive! делаем redirect_to index → страница перезагружается, архивная
  # строка уходит из .active-списка (паттерн архивации kanban-досок).
  def archive
    @client_request = find_record ClientRequest
    @client_request.archive!
    redirect_to client_requests_path, notice: t('.archived')
  end

  def unarchive
    @client_request = find_record ClientRequest
    @client_request.unarchive!
    redirect_to archived_requests_client_requests_path, notice: t('.unarchived')
  end

  # Список архивных запросов (read-only): кнопки смены статуса не показываем,
  # единственное действие в строке — «Разархивировать» (см. партиал).
  def archived_requests
    authorize ClientRequest
    @client_requests = ClientRequest.archived.recent.includes(:client, :item)
  end

  # История изменений (иконка часов) — читает HistoryRecord, как в clients#history.
  def history
    @client_request = find_record ClientRequest
    @records = @client_request.history_records.order(created_at: :desc)
    render 'shared/show_history'
  end

  private

  # Счётчики для бейджей на чипах. group(:status).count в Rails 5.1 может вернуть
  # ключами либо integer-коды, либо строковые имена — нормализуем к именам enum,
  # чтобы во вью обращаться по строковому ключу статуса.
  def status_counts
    # Только активные — архивные не учитываем в счётчиках чипов.
    ClientRequest.active.group(:status).count.each_with_object(Hash.new(0)) do |(key, count), acc|
      name = key.is_a?(Integer) ? ClientRequest.statuses.key(key) : key.to_s
      acc[name] = count
    end
  end

  def client_request_params
    params.require(:client_request).permit(:client_id, :item_id, :reason)
  end

  # При редактировании клиента не меняем (запрос привязан к тому же клиенту);
  # зато разрешаем устройство, комментарий и ручную дату покупки.
  def client_request_edit_params
    params.require(:client_request).permit(:item_id, :reason, :sold_at)
  end

  # Datepicker шлёт дату как 'дд.мм.гггг'. Date.parse на таком формате
  # неоднозначен (06.07 → день или месяц?), поэтому разбираем строго strptime.
  def parse_sold_at(value)
    return if value.blank?

    Date.strptime(value, '%d.%m.%Y')
  rescue ArgumentError
    nil
  end

  # Разрешаем менять только workflow-статус. purchase_check_status выставляется
  # автоматически 1С-джобой либо вручную через форму редактирования (ввод даты),
  # но НЕ через эту кнопку — иначе sold_at и статус проверки рассинхронизируются.
  def status_params
    params.require(:client_request).permit(:status)
  end
end
