# frozen_string_literal: true

class UsersController < ApplicationController
  before_action :load_infos, only: %i[show profile]

  def index
    authorize User

    @users = User.search(sanitized_search_params).id_asc.page(params[:page])
    @current_city = params[:city]

    respond_to do |format|
      format.html
      format.json { render json: { users: @users.map(&:short_name) } }
    end
  end

  def search
    authorize User
    @users = User.search(params[:query]).page(params[:page]) || []

    respond_to do |format|
      format.json { render json: @users.map { |u| {id: u.id, username: u.username, short_name: u.short_name} } }
      format.js { render :search }
    end
  end

  def show
    @user = find_record User.includes(comments: :user)
    @service_jobs = @user.service_jobs.not_at_archive.newest
    @schedule_month = Date.current
    load_schedule_calendar_data
    @assignments_month = Date.current
    load_assignments_calendar_data

    respond_to do |format|
      format.html
      format.json { render json: @user }
    end
  end

  def new
    @user = authorize User.new
    respond_to do |format|
      format.html { render 'form' }
      format.json { render json: @user }
    end
  end

  def edit
    @user = find_record User
    respond_to do |format|
      format.html { render 'form' }
      format.json { render json: @user }
    end
  end

  def create
    filtered_params = user_params.tap { |p| filter_ability_ids_for_limited_rights(p) }
    @user = authorize User.new(filtered_params)

    respond_to do |format|
      if @user.save
        format.html do
          if params[:user][:photo].present?
            render :crop
          else
            redirect_to @user, notice: t('users.created')
          end
        end
        format.json { render json: @user, status: :created, location: @user }
      else
        format.html { render 'form' }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @user = find_record User

    if params[:user][:rehire] == '1'
      rehire_date = params[:user][:rehire_date].present? ? Date.parse(params[:user][:rehire_date]) : Date.current
      rehire_reason = params[:user][:rehire_reason]
      @user.rehire!(rehire_date: rehire_date, rehire_reason: rehire_reason)
      redirect_to @user, notice: t('users.rehired')
      return
    end

    respond_to do |format|
      if @user.update_attributes(params_for_update)
        format.html do
          if params[:user][:photo].present?
            render :crop
          else
            redirect_to @user, notice: t('users.updated')
          end
        end
        format.json { head :no_content }
        format.js { render 'shared/close_modal_form' }
      else
        @salaries = @user.salaries
        @installments = @user.installments
        format.html { render 'form' }
        format.json { render json: @user.errors, status: :unprocessable_entity }
        format.js { render 'shared/show_modal_form' }
      end
    end
  end

  def update_uniform
    @user = find_record User
    @user.update_attributes(uniform_params)
    respond_to(&:js)
  end

  def update_user_settings
    @user = find_record User
    @user.user_settings.update(user_settings_params)
    redirect_to @user
  end

  def update_photo
    @user = find_record User
    @user.update_attributes(photo_params)
    respond_to do |format|
      format.html do
        if params[:user][:photo].present?
          render :crop
        else
          redirect_to @user
        end
      end
    end
  end

  def update_self
    @user = find_record User
    @user.update_attributes(update_self_params)
    respond_to do |format|
      format.html { redirect_to :profile }
    end
  end

  def destroy
    @user = find_record User
    @user.destroy

    respond_to do |format|
      format.html { redirect_to users_url }
      format.json { head :no_content }
    end
  end

  def profile
    @user = authorize current_user
    @service_jobs = @user.service_jobs.not_at_archive.newest
    @schedule_month = Date.current
    load_schedule_calendar_data
    @assignments_month = Date.current
    load_assignments_calendar_data

    respond_to do |format|
      format.html { render 'show' }
      format.json { render json: @user }
    end
  end

  def duty_calendar
    @user = find_record User
    respond_to(&:js)
  end

  def schedule_calendar
    @user = find_record User
    @schedule_month = params[:date].blank? ? Date.current : params[:date].to_date
    load_schedule_calendar_data
    respond_to(&:js)
  end

  def assignments_calendar
    @user = find_record User
    @assignments_month = params[:date].blank? ? Date.current : params[:date].to_date
    load_assignments_calendar_data
    respond_to(&:js)
  end

  def staff_duty_schedule
    authorize User
    @calendar_month = params[:date].blank? ? Date.current : params[:date].to_date
    respond_to(&:js)
  end

  def update_wish
    @user = find_record User

    respond_to do |format|
      if @user.update_attributes(wish: params[:user_wish])
        format.json { render json: { wish: @user.wish } }
      else
        format.json { render json: { error: 'error' } }
      end
    end
  end

  def schedule
    authorize User
    @users = User.includes(:duty_days, :department, :location).active.schedulable.id_asc
    @locations = Location.for_schedule.in_city(current_city)
    @departments = Department.in_city(current_city)
  end

  def add_to_job_schedule
    @msg = ''
    @user = find_record User
    @day = params[:day]
    @msg = 'User location not set' if (@location_id = @user.location.try(:id)).nil?
    @schedule_day = @user.schedule_days.find_by_day @day
  end

  def rating
    authorize User
    @users = User.active.staff.id_asc
  end

  def create_duty_day
    @duty_day = authorize DutyDay.new(duty_day_params), :manage?
    @duty_day.save
    @day = @duty_day.day
    @kind = @duty_day.kind
    render 'update_duty_day'
  end

  def destroy_duty_day
    duty_day = authorize DutyDay.find(params[:duty_day_id]), :manage?
    @day = duty_day.day
    @kind = duty_day.kind
    duty_day.destroy
    render 'update_duty_day'
  end

  def actions
    @user = find_record User

    respond_to(&:html)
  end

  def finance
    @user = find_record User
    @salaries = @user.salaries
    @installments = @user.installments

    respond_to do |format|
      format.js { render 'shared/show_modal_form' }
    end
  end

  def bonuses
    @user = find_record User
    @bonuses = @user.bonuses
    respond_to(&:js)
  end

  def experience
    authorize User
    @users = User.oncoming_salary
    head(:no_content) if @users.empty?
  end

  def update_elqueue_window
    @user = find_record User
    respond_to do |format|
      if @user.update!(elqueue_window_params)
        @user.pause!
        current_user.reload
        format.js
      else
        format.js { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  def remember_pause
    authorize User
    @users = User.where(remember_pause: true)
  end

  def unset_remember_pause
    @user = find_record User
    @user.unset_remember_pause
    redirect_to remember_pause_users_path, notice: 'Статус удален'
  end

  private

  def load_schedule_calendar_data
    range = @schedule_month.beginning_of_month..@schedule_month.end_of_month
    schedule_group = @user.schedule_group_membership&.schedule_group
    @schedule_entries_index = if schedule_group
      schedule_group.schedule_entries
        .where(user: @user, date: range)
        .includes(:shift, :occupation_type, department: :schedule_config)
        .index_by(&:date)
    else
      {}
    end
  end

  def load_assignments_calendar_data
    month = @assignments_month
    @duty_entries_index = DutyScheduleEntry.where(user: @user).for_month(month).includes(:department).index_by(&:date)
    @cashier_entries_index = CashierScheduleEntry.where(user: @user).for_month(month).includes(:department).index_by(&:date)
    @store_closing_entries_index = StoreClosingEntry.where(user: @user).for_month(month).includes(:department).index_by(&:date)

    user_dates = (@duty_entries_index.keys + @cashier_entries_index.keys + @store_closing_entries_index.keys).to_set
    @other_duty_dates = DutyScheduleEntry.where.not(user: @user).for_month(month).distinct.pluck(:date).to_set - user_dates
    @other_cashier_dates = CashierScheduleEntry.where.not(user: @user).for_month(month).distinct.pluck(:date).to_set - user_dates
    @other_store_closing_dates = StoreClosingEntry.where.not(user: @user).for_month(month).distinct.pluck(:date).to_set - user_dates

    @upcoming_duties = DutyScheduleEntry.where('date >= ?', Date.current).includes(:user, :department).order(:date).limit(10)
    @upcoming_cashier = CashierScheduleEntry.where('date >= ?', Date.current).includes(:user, :department).order(:date).limit(10)
    @upcoming_store_closing = StoreClosingEntry.where('date >= ?', Date.current).includes(:user, :department).order(:date).limit(10)
  end

  def load_infos
    # @infos = Info.actual.available_for(current_user).grouped_by_date.limit 20
    @infos = policy_scope(Info).actual.available_for(current_user).newest.limit(20)
  end

  def elqueue_window_params
    params.require(:user).permit(:elqueue_window_id)
  end

  def uniform_params
    params.require(:user).permit(:uniform_sex, :uniform_size)
  end

  def user_settings_params
    params.require(:user_settings).permit(:fixed_main_menu, :auto_department_detection, :receive_location_task_notifications, :receive_glass_sticking_notifications)
  end

  def update_self_params
    params.require(:user).permit(:hobby, wishlist: [])
  end

  def duty_day_params
    params.require(:duty_day).permit(:day, :user_id, :kind)
  end

  def params_for_update
    user_params.tap do |p|
      if p[:password].blank?
        p.delete(:password)
        p.delete(:password_confirmation)
      end

      p.delete :hiring_date

      # Scheduled dismissal: if dismissed_date is in the future, don't set is_fired yet
      if p[:is_fired] == '1' && p[:dismissed_date].present?
        dismissed = Date.parse(p[:dismissed_date]) rescue nil
        if dismissed && dismissed > Date.current
          p[:is_fired] = '0'
        end
      end

      filter_ability_ids_for_limited_rights(p)
    end
  end

  def filter_ability_ids_for_limited_rights(p)
    return if current_user.superadmin?
    return unless p.key?(:ability_ids)

    if policy(User).manage_limited_rights?
      admin_assignable_ids = Ability.admin_assignable.pluck(:id).map(&:to_s)
      submitted_ids = Array(p[:ability_ids]).reject(&:blank?)

      # Keep only admin_assignable from submitted
      allowed_submitted = submitted_ids & admin_assignable_ids

      # Preserve existing non-admin-assignable abilities
      existing_protected = @user&.ability_ids&.map(&:to_s)&.reject { |id| admin_assignable_ids.include?(id) } || []

      p[:ability_ids] = allowed_submitted + existing_protected
    else
      p.delete(:ability_ids)
    end
  end

  def sanitized_search_params
    params = search_params
    params.delete(:all) if params.key?(:all) && !can?(:see_all_users, User)
    params
  end

  def user_params
    params.require(:user).permit(
      :username, :email, :card_number, :password, :password_confirmation, :name, :patronymic, :surname, :phone_number,
      :session_duration, :abilities_mask, :activities_mask, :birthday, :can_help_in_mac_service, :can_help_in_repair,
      :department_autochangeable, :department_id, :location_id, :hiring_date, :hobby, :is_fired, :job_title, :color,
      :position, :prepayment, :role, :salary_date, :schedule,:store_id, :uniform_sex, :uniform_size, :wish, :wishlist,
      :photo, :photo_cache, :remove_photo, :work_phone, :service_job_sorting_id, :is_senior,
      :dismissed_date, :dismissal_reason_id, :dismissal_comment,

      ability_ids: [], activities: [],
      schedule_days: [:day, :hours, :user, :user_id],
      duty_days: [:day, :user_id, :kind],
      karmas: [:comment, :user_id, :karma_group_id, :good],
      salaries: [:amount, :user, :user_id, :issued_at, :comment, :is_prepayment],
      installment_plans: [:cost, :issued_at, :object, :user, :user_id, :installments_attributes, :is_closed],
      installment: {}
    )
    # TODO: check nested attributes for: schedule_days, duty_days, karmas, salaries, installment_plans
  end

  def photo_params
    params.require(:user)
          .permit(:photo, :photo_cache, :remove_photo, :photo_crop_x, :photo_crop_y, :photo_crop_w, :photo_crop_h)
  end
end
