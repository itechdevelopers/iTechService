# frozen_string_literal: true

class ProductsController < ApplicationController
  skip_after_action :verify_authorized, except: %i[create update destroy remains_in_store show_prices show_remains]

  def index
    @product_groups = ProductGroup.roots.ordered
    if params[:group].blank?
      @opened_product_groups = []
      @products = Product.search(search_params)
    else
      @current_product_group = ProductGroup.find params[:group]
      @opened_product_groups = @current_product_group.path_ids[1..-1].map { |g| "product_group_#{g}" } # .join(', ')
      @products = @current_product_group.products.search(search_params)
    end

    @products = @products.available if params[:form] == 'sale'
    @products = @products.preload(:product_group, :product_category)
    @products = @products.page(params[:page])

    params[:table_name] = 'small_table' if params[:choose] == 'true'

    respond_to do |format|
      format.html
      format.js
      format.json { render json: @products }
    end
  end

  def show
    # TODO: optimize query
    @product = find_record Product
    @items = @product.items.available
    respond_to do |format|
      format.html
      format.json { render json: @product }
      format.pdf do
        unless @product.barcode_num
          head :no_content
          return
        end

        filename = "product_tag_#{@product.barcode_num}.pdf"
        if params[:print]
          pdf = ProductTagPdf.new @product, view_context, params
          filepath = "#{Rails.root}/tmp/pdf/#{filename}"
          pdf.render_file filepath
          PrinterTools.print_file filepath, type: :tags, printer: current_department.printer
        else
          pdf = ProductTagPdf.new @product, view_context, params
        end
        send_data pdf.render, filename: filename, type: 'application/pdf', disposition: 'inline'
      end
    end
  end

  def new
    @product = authorize Product.new(product_params)
    respond_to do |format|
      format.html { render 'form' }
      format.json { render json: @product }
    end
  end

  def edit
    @product = find_record Product
    respond_to do |format|
      format.html { render 'form' }
    end
  end

  def create
    @product = authorize Product.new(product_params)
    respond_to do |format|
      if @product.save
        @product.items.create
        format.html { redirect_to @product, notice: t('products.created') }
        format.json { render json: @product, status: :created, location: @product }
      else
        format.html { render 'form' }
        format.json { render json: @product.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @product = find_record Product
    respond_to do |format|
      if @product.update_attributes(product_params)
        format.html { redirect_to @product, notice: t('products.updated') }
        format.json { head :no_content }
      else
        format.html { render 'form' }
        format.json { render json: @product.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @product = find_record Product
    @product.destroy
    respond_to do |format|
      format.html { redirect_to products_url }
      format.json { head :no_content }
    end
  end

  def find
    @product = Product.find_by_group_and_options(params[:product_group_id], params[:option_ids])
    if @product.present?
      @item = @product.items.build
      @item.features.build @product.feature_types.map { |ft| { feature_type_id: ft.id } }
    end
  end

  def choose
    search_params = params.permit(:form, :store_kind, :user_role).to_h.symbolize_keys.merge(roots: true)
    @product_groups = ProductGroup.search(**search_params).ordered
    @product = Product.find params[:product_id] if params[:product_id].present?
    params[:form_name] = 'products/choose_form'
    respond_to do |format|
      format.js
    end
  end

  def select
    @store = Store.find params[:store_id] if params[:store_id].present?
    @client = Client.find params[:client_id] if params[:client_id].present?

    if params[:product_id].present?
      @product = Product.find params[:product_id]
      if @product.feature_accounting
        @items = @product.items
        @items = @items.available if params[:form].in? %w[movement_act deduction_act]
        @items = @items.in_store(@store) if @store.present?
        @items = @items.page(params[:page])
        @feature_types = @product.feature_types
      else
        @item = @product.items.first
      end
    end

    @item = Item.find params[:item_id] if params[:item_id].present?

    @item = Item.create params[:item] if params[:item].present?

    respond_to do |format|
      format.js
    end
  end

  def choose_group
    @product_groups = ProductGroup.includes(:product_category, :products).roots.ordered
  end

  def select_group
    @product_group = ProductGroup.find(params[:product_group_id])
  end

  def category_select
    category = Category.find params[:category_id]
    @feature_types = category.feature_types
  end

  def show_prices
    @product = find_record Product
    @product_prices = @product.prices.page(params[:page])
    respond_to do |format|
      format.js
    end
  end

  def show_remains
    @product = find_record Product
    @stores = Store.all
    # @store_items = @product.store_items.order('store_id asc')
    respond_to do |format|
      format.js
    end
  end

  def remains_in_store
    product = find_record Product
    store = Store.find params[:store_id]
    quantity = product.quantity_in_store store
    respond_to do |format|
      format.json { render json: { quantity: quantity } }
    end
  end

  def related
    @product = find_record Product
    @related_products = @product.related_products.limit(5)
    @related_product_groups = @product.related_product_groups.limit(5)
    respond_to do |format|
      format.js
    end
  end

  private

  def update_barcode_num
    if (item_params = params.dig(:product, :item))
      item = Item.find(item_params[:id])
      item.update(barcode_num: item_params[:barcode_num])
    end
  end

  def product_params
    params.require(:product)
          .permit(:code, :comment, :device_type_id, :name, :product_category_id, :product_group_id,
                  :quantity_threshold, :warranty_term,
                  option_ids: [],
                  items: [:product, :product_id, :features_attributes, :barcode_num],
                  task: [:cost, :duration, :name, :code, :priority, :role, :location_code, :product_id, :hidden],
                  store_products: [:warning_quantity, :store_id, :product_id]
          )
    # TODO: check nested attributes for: items, task, store_products
  end
end
