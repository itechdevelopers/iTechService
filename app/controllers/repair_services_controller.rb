# frozen_string_literal: true

class RepairServicesController < ApplicationController
  def index
    authorize RepairService
    @repair_groups = RepairGroup.roots.order('name asc')

    @repair_services = RepairService.includes(spare_parts: :product).in_group(params[:group]) if params[:group].present?

    params[:table_name] = {
      'prices' => 'prices_table',
      'choose' => 'choose_table'
    }.fetch(params[:mode], 'table')

    params[:department_id] ||= current_department.id

    respond_to do |format|
      format.html
      format.js
    end
  end

  def show
    @repair_service = find_record RepairService
    respond_to do |format|
      format.html
    end
  end

  def new
    @repair_service = authorize RepairService.new
    build_prices
    respond_to do |format|
      format.html { render 'form' }
    end
  end

  def edit
    @repair_service = find_record RepairService
    build_prices
    respond_to do |format|
      format.html { render 'form' }
    end
  end

  def create
    @repair_service = authorize RepairService.new(repair_service_params)
    respond_to do |format|
      if @repair_service.save
        format.html { redirect_to repair_services_path, notice: t('repair_services.created') }
      else
        format.html { render 'form' }
      end
    end
  end

  def update
    @repair_service = find_record RepairService
    respond_to do |format|
      if @repair_service.update_attributes(repair_service_params)
        format.html { redirect_to repair_services_path, notice: t('repair_services.udpated') }
      else
        format.html { render 'form' }
      end
    end
  end

  def mass_update
    authorize RepairService
    params[:repair_services].each do |id, value|
      price = RepairPrice.find_by(repair_service_id: id, department_id: params[:department_id])
      price.update value: value
    end
    redirect_to repair_services_path(params.slice(:mode, :department_id, :group))
  end

  def destroy
    @repair_service = find_record RepairService
    @repair_service.destroy
    respond_to do |format|
      format.html { redirect_to repair_services_url }
    end
  end

  def choose
    authorize RepairService
    @repair_groups = RepairGroup.roots.order('id asc')
    respond_to do |format|
      format.js
    end
  end

  def select
    @repair_service = find_record RepairService
    respond_to do |format|
      format.js
    end
  end

  private

  def build_prices
    Department.real.each do |department|
      @repair_service.prices.find_or_initialize_by(department_id: department.id)
    end
  end

  def repair_service_params
    params.require(:repair_service)
          .permit(:client_info, :difficult, :is_body_repair, :is_positive_price, :name, :repair_group_id,
                    spare_parts: [:quantity, :warranty_term, :repair_service_id, :product_id],
                    prices: [:value, :repair_service_id, :department_id]
                  )
    # TODO: check nested attributes for: spare_parts, prices
  end
end
