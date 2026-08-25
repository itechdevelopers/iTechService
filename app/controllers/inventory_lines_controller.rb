# frozen_string_literal: true

# Ручная правка списка ревизии товароведом: убрать лишнюю позицию, добавить
# забытую. Правится только черновик — после отправки на филиал список менять
# нельзя, у технарей он уже на руках.
class InventoryLinesController < ApplicationController
  before_action :load_inventory

  def create
    item = item_to_add

    if item.blank?
      @error = t('.not_found')
    elsif @inventory.lines.exists?(item_id: item.id)
      @error = t('.already_added', name: item.name)
    else
      @inventory.lines.create!(
        item: item,
        position: @inventory.next_position,
        snapshot_name: item.name,
        snapshot_purchase_price: item.purchase_price
      )
    end

    @found_products = SparePartSearch.call(params[:q])
    render 'update_lines'
  end

  def destroy
    line = @inventory.lines.find(params[:id])
    line.destroy
    @inventory.renumber_lines!

    @found_products = SparePartSearch.call(params[:q])
    render 'update_lines'
  end

  private

  def load_inventory
    @inventory = Inventory.find(params[:inventory_id])
    authorize @inventory, :manage_lines?
  end

  # Считаем в штуках экземпляр номенклатуры (Item), а не продукт: остаток
  # лежит на StoreItem(item_id, store_id). У обычной запчасти экземпляр один,
  # и если его ещё нет — заводим, иначе позицию нельзя ни посчитать, ни списать.
  def item_to_add
    product = Product.find_by(id: params[:product_id])
    return nil if product.blank? || product.feature_accounting

    product.items.first || product.items.create!
  end
end
