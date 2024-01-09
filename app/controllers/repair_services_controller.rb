# frozen_string_literal: true

class RepairServicesController < ApplicationController
  def index
    authorize RepairService
    @repair_groups = RepairGroup.roots.order('name asc')

    if params[:group].blank?
      @repair_services = RepairService.search(search_params[:query])
    else
      @repair_services = RepairService.includes(spare_parts: :product).in_group(params[:group])
      @repair_services = @repair_services.search(search_params[:query])
    end

    params[:table_name] = {
      'prices' => 'prices_table',
      'choose' => 'choose_table',
      'prices-all-branches' => 'all_branches_table'
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
    @repair_service = authorize RepairService.new(repair_service_params)
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
      # When updating several departments
      if value.is_a?(ActionController::Parameters)
        value.each do |dep_id, val|
          price = RepairPrice.find_by(repair_service_id: id, department_id: dep_id)
          val = 0 unless val.present?
          if price.nil?
            RepairPrice.create(repair_service_id: id, department_id: dep_id, value: val)
          else
            price.update value: val
          end
        end
      else
        price = RepairPrice.find_by(repair_service_id: id, department_id: params[:department_id])
        price.update value: value
      end
    end
    redirect_to repair_services_path(params.permit(:mode, :department_id, :group))
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
    params.require(:repair_service).permit(
      :name, :client_info, :repair_group_id, :is_positive_price, :difficult, :is_body_repair,
      spare_parts_attributes: [:id, :_destroy, :quantity, :warranty_term, :product_id],
      prices_attributes: [:id, :value, :department_id]
    )
  end
end
