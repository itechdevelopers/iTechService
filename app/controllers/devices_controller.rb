class DevicesController < ApplicationController
  before_action :set_device_groups, only: %i[new edit create update]

  def index
    authorize Item
    @devices = Item.filter(action_params)
  end

  def autocomplete
    authorize Item
    @devices = Item.filter(action_params).page(params[:page])

    respond_to do |format|
      format.json
    end
  end

  def show
    @device = find_record(Item.includes(:sales))
    set_imported_sales

    respond_to do |format|
      format.js
    end
  end

  def select
    @device = DeviceDecorator.decorate(find_record(Item))

    respond_to do |format|
      format.js
    end
  end

  def new
    @device = authorize Item.new

    respond_to do |format|
      format.js { render 'shared/show_secondary_form' }
    end
  end

  def edit
    @device = find_record Item

    respond_to do |format|
      format.js { render 'shared/show_secondary_form' }
    end
  end

  def create
    @device = authorize Item.new(device_params)

    respond_to do |format|
      if @device.save
        format.js { render 'save' }
      else
        format.js { render 'shared/show_secondary_form' }
      end
    end
  end

  def update
    @device = find_record Item

    respond_to do |format|
      if @device.update device_params
        format.js { render 'save' }
      else
        format.js { render 'shared/show_secondary_form' }
      end
    end
  end

  def destroy
    @device = find_record Item
    @device.destroy

    respond_to do |format|
      format.js
    end
  end

  private

  def set_device_groups
    @device_groups = ProductGroup.devices.arrange_as_array({order: 'position'})
  end

  def device_params
    params.require(:item).permit(:product_id, features_attributes: [:id, :feature_type_id, :value])
  end

  def set_imported_sales
    imported_sales = ImportedSale.search search: @device.serial_number
    imported_sales = ImportedSale.search search: @device.imei unless @imported_sales.present? && @device.imei.blank?
    @imported_sales = imported_sales
  end
end