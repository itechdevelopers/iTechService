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

  def destroy
    @inventory = find_record Inventory
    number = @inventory.number
    @inventory.destroy

    redirect_to inventories_path, notice: t('.destroyed', number: number)
  end

  private

  # Ищем только среди запчастей, и категория берётся с самого продукта, а не с
  # его группы: они расходятся — продукт может лежать в группе запчастей, но
  # числиться поэкземплярным «девайсом».
  #
  # Регистронезависимость через явную коллацию, а не LOWER(): база создана с
  # коллацией C, где lower() кириллицу не трогает и поиск «дисплей» никогда не
  # найдёт «Дисплей». Имя коллации спрашиваем у базы — на проде и на dev оно
  # пишется по-разному (Item.russian_collation).
  def search_products
    query = params[:q].to_s.strip
    return Product.none if query.blank?

    collation = Item.russian_collation
    condition = if collation
                  %(products.name ILIKE :q COLLATE "#{collation}")
                else
                  'LOWER(products.name) LIKE :q'
                end
    term = collation ? "%#{query}%" : "%#{query.mb_chars.downcase}%"

    Product.joins(:product_category)
           .where(product_categories: { kind: 'spare_part' })
           .where(condition, q: term)
           .limit(30)
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
