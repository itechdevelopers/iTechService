class DashboardController < ApplicationController
  skip_before_action :authenticate_user!, :set_current_user, only: :check_session_status
  skip_after_action :verify_authorized

  def index
    if current_user.marketing?
      load_actual_orders
      @table_name = 'orders_table'
    else
      load_actual_jobs
      @table_name = 'tasks_table'
    end
    respond_to do |format|
      format.html
      format.js
    end
  end

  def actual_orders
    load_actual_orders
    respond_to do |format|
      format.js
    end
  end

  def actual_tasks
    load_actual_jobs
    respond_to do |format|
      format.js
    end
  end

  def actual_supply_requests
    authorize SupplyRequest, :read?
    @supply_requests = policy_scope(SupplyRequest).actual.page params[:page]
    @table_name = 'requests_table'
    respond_to do |format|
      format.js
    end
  end

  def ready_service_jobs
    @service_jobs = ServiceJob.ready(current_department).order(done_at: :desc)
                      .search(service_job_search_params).page(params[:page])
    respond_to do |format|
      format.js
    end
  end

  def become
    if Rails.env.development?
      sign_in :user, User.find(params[:id])
    end
    redirect_to root_url
  end

  def check_session_status
    render json: {timeout: !user_signed_in?}
  end

  def print_tags; end

  private

  def load_actual_jobs
    @service_jobs = policy_scope(ServiceJob).includes(:client, :history_records, :location, :receiver, :user, :keeper, {device_tasks: :task, features: :feature_type})

    if service_job_search_params.empty?
      if current_user.any_admin?
        if params[:location].present?
          location = Location.find(params[:location])
          @service_jobs = @service_jobs.located_at(location)
          @location_name = location.name
        else
          @service_jobs = @service_jobs.in_department(current_department).pending
        end
      elsif current_user.technician?
        locations = Location.repair_mac_or_ios.in_department(current_department)
        @service_jobs = @service_jobs.located_at(locations)
      elsif current_user.location.present?
        @service_jobs = @service_jobs.located_at(current_user.location)
      else
        @service_jobs = @service_jobs.in_department(current_department)
      end
    else
      @product_group = ProductGroup.select(:name).find(params[:product_group_id]) if params.key?(:product_group_id)
      @service_jobs = @service_jobs.pending.search(service_job_search_params)
    end

    if current_user.able_to?(:print_receipt)
      @service_jobs = @service_jobs.newest
    else
      @service_jobs = @service_jobs.oldest
    end

    @service_jobs = @service_jobs.page(params[:page])
  end

  def load_actual_orders
    if current_user.technician?
      @orders = policy_scope(Order).actual_orders.technician_orders.search(search_params).oldest.page(params[:page])
    else
      @orders = policy_scope(Order).actual_orders.marketing_orders.search(search_params).oldest.page(params[:page])
    end
  end

  def service_job_search_params
    params.permit(:status, :location_id, :product_group_id, :ticket, :service_job, :client)
  end
end
