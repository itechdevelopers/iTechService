class DashboardController < ApplicationController
  skip_before_action :authenticate_user!, :set_current_user, only: :check_session_status
  skip_after_action :verify_authorized
  helper_method :sort_column, :sort_direction

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

  # TODO, refactor
  def load_actual_jobs
    @service_jobs = policy_scope(ServiceJob).includes(:client, :history_records, :location, :receiver, :user, :keeper, {device_tasks: :task, features: :feature_type})
    @current_sort = current_sort

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

      if params[:product_group_id].present?
        @product_group = ProductGroup.select(:name).find(params[:product_group_id])
        @service_jobs = @service_jobs.of_product_group(params[:product_group_id])
      end

      if params[:only].present?
        filter_type = params[:only]
        @service_jobs = case filter_type
                        when 'warning' then @service_jobs.return_in(1.hours.since..3.hours.since)
                        when 'danger' then @service_jobs.return_in(DateTime.current..1.hours.since)
                        when 'time-out' then @service_jobs.return_expired
                        else @service_jobs.return_after(3.hours.since)
                        end
      end

      save_sorting if params[:sort].present?
    else
      @service_jobs = @service_jobs.pending.search(service_job_search_params)
    end

    # @service_jobs = current_user.able_to?(:print_receipt) ? @service_jobs.newest : @service_jobs.oldest

    service_jobs_sorting
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
    params.permit(:status, :location_id, :ticket, :service_job, :client)
  end

  def sort_column
    ServiceJob.column_names.include?(params[:sort]) ? params[:sort] : 'other'
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : 'asc'
  end

  def save_sorting
    create_or_update_sort
  end

  def current_sort
    @current_sort = current_user.service_job_sorting || create_or_update_sort
  end

  def create_or_update_sort
    sort_title = params[:sort_title] || 'По умолчанию'
    sorting = ServiceJobSorting.find_by(user_id: current_user.id)

    if sorting.present?
      sorting.title = sort_title
      sorting.column = sort_column
      sorting.save
    else
      sorting = ServiceJobSorting.create(title: sort_title, direction: sort_direction, column: 'created_at', user_id: current_user.id)
    end

    current_user.service_job_sorting_id = sorting.id
    current_user.save

    sorting
  end

  def service_jobs_sorting
    @current_sort = ServiceJobSorting.find_by(user_id: current_user.id)

    case @current_sort.column
    when 'return_at' then @service_jobs = @service_jobs.order_return_at_asc
    when 'created_at' then @service_jobs = @service_jobs.order_created_at_asc
    else
      @service_jobs = @service_jobs.return_in_future.order_return_at_asc
    end
  end
end
