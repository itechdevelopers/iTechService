# frozen_string_literal: true

class ItemsController < ApplicationController
  def index
    authorize Item

    if params[:product_id].blank?
      @items = policy_scope(Item).search(action_params)
      @feature_types = []
      @items.each { |item| @feature_types + item.feature_types.to_a }
      @feature_types.uniq!
    else
      @product = Product.find(params[:product_id])
      @items = policy_scope(@product.items).search(action_params)
      @feature_types = @product.feature_types
    end

    # if (@form = params[:form]) == 'sale'
    #   @items = @items.available
    # end

    @table_name = 'small_table' if params[:choose] == 'true'

    if @items.many?
      @products = Product.where(id: @items.map(&:product_id))
      @products.page(params[:page])
    end

    @items = @items.page(params[:page])

    respond_to do |format|
      if @items.one?
        @item = @items.first
        @product ||= @item.product
        format.js { render 'products/select' }
        if params[:saleinfo].present?
          format.json { render json: @item.as_json.merge(@item.sale_info) }
        else
          format.json { render json: @item }
        end
      else
        format.html
        format.js
        format.json { render json: @items.any? ? @items : { message: t('devices.not_found') } }
      end
    end
  end

  def autocomplete
    @items = Item.filter(action_params).page(params[:page])
    respond_to do |format|
      format.json
    end
  end

  def show
    @item = find_record Item

    # respond_to do |format|
    #   format.pdf do
    #     filename = "product_tag_#{@item.barcode_num}.pdf"
    #     if params[:print]
    #       pdf = ProductTagPdf.new @item, view_context, params
    #       filepath = "#{Rails.root}/tmp/pdf/#{filename}"
    #       pdf.render_file filepath
    #       PrinterTools.print_file filepath, type: :tags, printer: current_department.printer
    #     else
    #       pdf = ProductTagPdf.new @item, view_context, params
    #     end
    #     send_data pdf.render, filename: filename, type: 'application/pdf', disposition: 'inline'
    #   end
    # end
  end

  def new
    @item = Item.new
    respond_to do |format|
      format.html
      format.json { render json: @item }
    end
  end

  def edit
    @item = find_record Item
    respond_to do |format|
      format.js { render 'shared/show_modal_form' }
    end
  end

  def create
    @item = authorize Item.new(item_params)
    respond_to do |format|
      if @item.save
        format.html { redirect_to @item, notice: 'Item was successfully created.' }
        format.json { render json: @item, status: :created, location: @item }
      else
        format.html { render action: 'new' }
        format.json { render json: @item.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @item = find_record Item
    respond_to do |format|
      if @item.update_attributes(item_params)
        format.js { render 'update' }
      else
        format.js { render 'shared/show_modal_form' }
      end
    end
  end

  def destroy
    @item = find_record Item
    @item.destroy

    respond_to do |format|
      format.html { redirect_to items_url }
      format.json { head :no_content }
    end
  end

  def remains_in_store
    item = find_record Item
    store = Store.find(params[:store_id])
    quantity = item.actual_quantity(store)
    respond_to do |format|
      format.json { render json: { quantity: quantity } }
    end
  end

  def check_status
    item = find_record(Item).decorate
    render json: { status: item.status, status_info: item.status_info }
  end

  def item_params
    params.require(:item)
          .permit(:barcode_num, :product_id,
                  features: [:value, :item, :item_id, :feature_type, :feature_type_id]
          )
    # TODO: check nested attributes for: features
  end
end
