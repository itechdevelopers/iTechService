# frozen_string_literal: true

class InventoriesController < ApplicationController
  def index
    authorize Inventory

    scope = policy_scope(Inventory).recent.includes(:store, :user, :department)
    scope = scope.where(store_id: params[:store_id]) if params[:store_id].present?
    scope = scope.where(status: params[:status]) if Inventory.statuses.key?(params[:status])

    @inventories = scope
  end

  def show
    @inventory = find_record Inventory
    @found_products = search_products

    respond_to do |format|
      format.html
      format.js # поиск позиции для добавления в список подменяет только результаты
    end
  end

  def new
    @inventory = authorize Inventory.new(sort_mode: :alphabetical)

    render 'form'
  end

  def create
    @inventory = authorize Inventory.new(inventory_params)
    @inventory.user = current_user

    if @inventory.save
      redirect_to @inventory, notice: t('.created', number: @inventory.number)
    else
      render 'form'
    end
  end

  def edit
    @inventory = find_record Inventory

    render 'form'
  end

  def update
    @inventory = find_record Inventory

    if @inventory.update(inventory_params)
      redirect_to @inventory, notice: t('.updated')
    else
      render 'form'
    end
  end

  # Страница «что считать»: дерево групп запчастей + точечный поиск позиций.
  def selection
    @inventory = find_record Inventory
    @root_groups = ProductGroup.spare_parts.roots.ordered
    @found_products = search_products

    respond_to do |format|
      format.html
      format.js # поиск подменяет только список найденных позиций
    end
  end

  # Группы приходят целиком (набор чекбоксов), продукт — по одному, кнопкой.
  def update_selection
    @inventory = find_record Inventory

    if params.key?(:group_ids)
      @inventory.selected_group_ids = Array(params[:group_ids]).reject(&:blank?)
    end

    toggle_product if params[:product_id].present?

    respond_to do |format|
      format.js
      format.html { redirect_to selection_inventory_path(@inventory) }
    end
  end

  # Разворот выбора в пронумерованные строки. Пересборка стирает прежние строки
  # вместе с ручными правками, поэтому предупреждение висит на кнопке.
  def build_lines
    @inventory = find_record Inventory
    count = InventoryLinesBuilder.call(@inventory)

    if count.zero?
      redirect_to @inventory, alert: t('.empty')
    else
      redirect_to @inventory, notice: t('.built', count: count)
    end
  end

  # Технарь начинает подсчёт: фиксируется момент и остатки по учёту.
  def start
    @inventory = find_record Inventory
    @inventory.start!

    redirect_to @inventory, notice: t('.started')
  end

  # Возврат части позиций на пересчёт. Прежний факт по ним стирается — иначе
  # технарь подтвердит уже вписанное число не пересчитывая.
  def request_recount
    @inventory = find_record Inventory

    lines = @inventory.lines.where(id: Array(params[:line_ids]))
    if lines.empty?
      redirect_to @inventory, alert: t('.nothing_selected')
      return
    end

    Inventory.transaction do
      lines.each(&:request_recount!)
      @inventory.update!(status: :recount)
    end

    InventoryNotifier.notify_recount(@inventory, lines.size)
    redirect_to @inventory, notice: t('.requested', count: lines.size)
  end

  # «Ревизия готова»: результат уходит товароведу.
  def submit
    @inventory = find_record Inventory
    @inventory.update!(status: :submitted, submitted_at: Time.zone.now)
    InventoryNotifier.notify_submitted(@inventory)

    redirect_to @inventory, notice: t('.submitted', count: @inventory.discrepancy_lines.count)
  end

  # Модалка перед отправкой: показывает, кого уведомим автоматически, и даёт
  # добавить людей вручную.
  def send_picker
    @inventory = find_record Inventory
    @auto_recipients = InventoryNotifier.new(@inventory).recipients
    @available_users = additional_recipients_scope

    render 'shared/show_modal_form'
  end

  # Отправка на филиал: статус, момент отправки, запомненные адресаты и рассылка.
  def send_to_branch
    @inventory = find_record Inventory

    # Скоуп проверяем повторно на сервере: id в форме можно подменить.
    ids = Array(params[:user_ids]).map(&:to_i) & additional_recipients_scope.ids
    @inventory.subscribers = User.where(id: ids)
    @inventory.update!(status: :sent, sent_at: Time.zone.now)

    @notified_count = InventoryNotifier.notify_sent(@inventory)
    # flash, а не notice в redirect: JS-ветка закрывает модалку и перезагружает
    # страницу сама, и сообщение должно пережить эту перезагрузку.
    flash[:notice] = t('.sent', count: @notified_count)

    respond_to do |format|
      format.js
      format.html { redirect_to @inventory }
    end
  end

  def destroy
    @inventory = find_record Inventory
    number = @inventory.number
    @inventory.destroy

    redirect_to inventories_path, notice: t('.destroyed', number: number)
  end

  private

  def search_products
    SparePartSearch.call(params[:q])
  end

  # Дополнительно уведомить можно кого угодно из действующих сотрудников:
  # ревизию филиала часто курирует человек из другого подразделения.
  def additional_recipients_scope
    User.active.includes(:department, :location)
  end

  def toggle_product
    product = Product.find_by(id: params[:product_id])
    return if product.blank?

    selection = @inventory.selections.find_by(selectable: product)
    selection ? selection.destroy : @inventory.selections.create(selectable: product)
  end

  def inventory_params
    params.require(:inventory).permit(
      :store_id, :sort_mode, :ignore_model_in_sort, :include_zero_remnants, :comment
    )
  end
end
