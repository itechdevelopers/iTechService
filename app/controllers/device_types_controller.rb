# frozen_string_literal: true

class DeviceTypesController < ApplicationController
  def index
    authorize DeviceType
    @device_types = policy_scope(DeviceType).order('ancestry asc').page(params[:page])
    @device_type = DeviceType.new

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @device_types }
    end
  end

  def create
    @device_type = authorize DeviceType.new(device_type_params)

    respond_to do |format|
      if @device_type.save
        format.html { redirect_to device_types_path, notice: t('device_types.created') }
        format.json { render json: @device_type, status: :created, location: @device_type }
      else
        format.html { render action: 'new' }
        format.json { render json: @device_type.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
    @device_type = find_record DeviceType
  end

  def update
    @device_type = find_record DeviceType

    respond_to do |format|
      if @device_type.update_attributes(params[:device_type])
        format.js { render 'edit' }
        format.json { head :no_content }
      else
        format.js { render 'edit' }
        format.json { render json: @device_type.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @device_type = find_record DeviceType
    @device_type.destroy

    respond_to do |format|
      format.json { head :no_content }
    end
  end

  def reserve
    @device_type = find_record DeviceType
    new_reserve = @device_type.qty_reserve || 0
    new_reserve = new_reserve.next if params[:direction] == '+'
    new_reserve = new_reserve.pred if params[:direction] == '-'
    @device_type.update_attribute :qty_reserve, new_reserve
  end

  def device_type_params
    params.require(:device_type)
          .permit(:ancestry, :code_1c, :expected_during, :name, :qty_for_replacement, :qty_replaced, :qty_reserve, :qty_shop, :qty_store)
  end
end
