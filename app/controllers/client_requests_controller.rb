# frozen_string_literal: true

class ClientRequestsController < ApplicationController
  def index
    authorize ClientRequest
    @client_requests = ClientRequest.recent.includes(:client, :item)
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

  # История изменений (иконка часов) — читает HistoryRecord, как в clients#history.
  def history
    @client_request = find_record ClientRequest
    @records = @client_request.history_records.order(created_at: :desc)
    render 'shared/show_history'
  end

  private

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
