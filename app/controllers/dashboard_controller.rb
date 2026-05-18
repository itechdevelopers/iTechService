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
      load_repair_status_summary
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
    load_repair_status_summary
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

  def repair_status_devices
    repair_locations = resolve_repair_locations_for_summary
    return head :forbidden if repair_locations.blank?

    @status_code = params[:status_code].to_s
    @pause_reason = nil
    @scope_label = repair_summary_scope_label(repair_locations)

    base = ServiceJob.pending
             .located_at(repair_locations)
             .joins(:repair_status)
             .where(repair_statuses: { archived: false })
             .where.not(repair_statuses: { code: RepairStatus::COMPLETED })
             .includes(:client, :location, :repair_status, :repair_pause_reason,
                       item: { product: :product_group })

    case @status_code
    when 'total'
      @service_jobs = base
    when RepairStatus::WAITING, RepairStatus::IN_PROGRESS, RepairStatus::PAUSED
      @service_jobs = base.where(repair_statuses: { code: @status_code })
      if @status_code == RepairStatus::PAUSED
        all_paused_for_reason_counts = base.where(repair_statuses: { code: RepairStatus::PAUSED })
        @pause_reason_counts = all_paused_for_reason_counts.group(:repair_pause_reason_id).count
        if params[:pause_reason_id].present?
          @pause_reason = RepairPauseReason.find_by(id: params[:pause_reason_id])
          @service_jobs = @service_jobs.where(repair_pause_reason_id: @pause_reason.id) if @pause_reason
        end
      end
    else
      return head :bad_request
    end

    @service_jobs = @service_jobs.order(:return_at).to_a
    @include_technician = [RepairStatus::IN_PROGRESS, 'total'].include?(@status_code)
    @current_technicians = @include_technician ? load_current_technicians_for(@service_jobs) : {}

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
          @service_jobs = location.is_done? ? @service_jobs.located_at(location) : @service_jobs.pending.located_at(location)
          @location = location
          @location_name = location.name
        else
          @service_jobs = @service_jobs.in_department(current_department).pending
        end
      elsif current_user.technician?
        locations = Location.repair_mac_or_ios.in_department(current_department)
        @service_jobs = @service_jobs.pending.located_at(locations)
      elsif current_user.able_to?(:perform_engraving_tasks)
        @service_jobs = load_engraving_user_jobs(@service_jobs).pending
      elsif current_user.location.present?
        @service_jobs = @service_jobs.pending.located_at(current_user.location)
      else
        @service_jobs = @service_jobs.in_department(current_department).pending
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

  def load_repair_status_summary
    repair_locations = resolve_repair_locations_for_summary
    return @repair_status_summary = nil if repair_locations.blank?

    counts_by_code = ServiceJob.pending
                       .located_at(repair_locations)
                       .joins(:repair_status)
                       .where(repair_statuses: { archived: false })
                       .where.not(repair_statuses: { code: RepairStatus::COMPLETED })
                       .group('repair_statuses.code')
                       .count

    statuses = RepairStatus.active.ordered.where.not(code: RepairStatus::COMPLETED)

    @repair_status_summary = {
      total: counts_by_code.values.sum,
      statuses: statuses.map { |s| { code: s.code, name: s.name, color: s.color, count: counts_by_code[s.code].to_i } },
      location_name: repair_summary_scope_label(repair_locations)
    }
  end

  # nil → не показываем виджет (юзер не имеет отношения к repair-локациям)
  def resolve_repair_locations_for_summary
    if current_user.any_admin?
      if params[:location].present?
        loc = Location.find_by(id: params[:location])
        loc&.is_any_repair? ? [loc] : nil
      else
        Location.in_department(current_department).where(code: %w[repair repairmac repair_notebooks]).to_a.presence
      end
    elsif current_user.location&.is_any_repair?
      [current_user.location]
    end
  end

  def repair_summary_scope_label(locations)
    locations.size == 1 ? locations.first.name : t('dashboard.repair_status_summary.all_repair_locations', default: 'Все локации ремонта')
  end

  # Возвращает { service_job_id => { user:, changed_at: } } — последний переход в in_progress
  def load_current_technicians_for(service_jobs)
    sj_ids = service_jobs.select { |sj| sj.repair_status&.in_progress? }.map(&:id)
    return {} if sj_ids.empty?

    in_progress_status = RepairStatus.find_by(code: RepairStatus::IN_PROGRESS)
    return {} unless in_progress_status

    last_ids = RepairStatusChange.where(to_status_id: in_progress_status.id, service_job_id: sj_ids).group(:service_job_id).maximum(:id).values
    RepairStatusChange.includes(:user).where(id: last_ids).each_with_object({}) do |change, memo|
      memo[change.service_job_id] = { user: change.user, changed_at: change.changed_at }
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

  def load_engraving_user_jobs(base_scope)
    # Collect IDs from three different sources
    job_ids = []
    
    # Jobs at user's location (if any)
    if current_user.location.present?
      job_ids += base_scope.located_at(current_user.location).pluck(:id)
    end
    
    # Jobs at laser location
    laser_locations = Location.where(code: 'laser').in_department(current_department)
    job_ids += base_scope.located_at(laser_locations).pluck(:id)
    
    # Jobs with laser tasks
    job_ids += base_scope.joins(device_tasks: :task)
                        .where(tasks: { code: 'laser' })
                        .pluck('DISTINCT service_jobs.id')
    
    # Return service jobs matching any of the collected IDs
    job_ids.uniq!
    base_scope.where(id: job_ids)
  end
end
