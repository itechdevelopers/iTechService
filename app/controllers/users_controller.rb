# frozen_string_literal: true

class UsersController < ApplicationController
  before_action :load_infos, only: %i[show profile]

  def index
    authorize User
    @users = policy_scope(User).search(search_params).id_asc.page(params[:page]).per(50)

    respond_to do |format|
      format.html
      format.json { render json: { users: @users.map(&:short_name) } }
    end
  end

  def search
    authorize User
    @users = User.search(params[:query]) || []

    respond_to do |format|
      format.json { render json: @users.map {|u| {id: u.id, username: u.username, short_name: u.short_name}} }
    end
  end

  def show
    @user = find_record User.includes(comments: :user)
    @service_jobs = @user.service_jobs.not_at_archive.newest

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
    @user = authorize User.new(user_params)

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
    respond_to do |format|
      format.js
    end
  end

  def update_user_settings
    @user = find_record User
    @user.update_attributes(user_settings_params)
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

    respond_to do |format|
      format.html { render 'show' }
      format.json { render json: @user }
    end
  end

  def duty_calendar
    @user = find_record User
    respond_to do |format|
      format.js
    end
  end

  def staff_duty_schedule
    authorize User
    @calendar_month = params[:date].blank? ? Date.current : params[:date].to_date
    respond_to do |format|
      format.js
    end
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

    respond_to do |format|
      format.html
    end
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
    respond_to do |format|
      format.js
    end
  end

  def experience
    authorize User
    @users = User.oncoming_salary
    head(:no_content) if @users.empty?
  end

  private

  def load_infos
    # @infos = Info.actual.available_for(current_user).grouped_by_date.limit 20
    @infos = policy_scope(Info).actual.available_for(current_user).newest.limit(20)
  end

  def uniform_params
    params.require(:user).permit(:uniform_sex, :uniform_size)
  end

  def user_settings_params
    params.require(:user).permit(:fixed_main_menu)
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
    end
  end

  def user_params
    params.require(:user).permit(
      :username, :email, :card_number, :password, :password_confirmation, :name, :patronymic, :surname, :phone_number,
      :session_duration, :abilities_mask, :activities_mask, :birthday, :can_help_in_mac_service, :can_help_in_repair,
      :department_autochangeable, :department_id, :location_id, :hiring_date, :hobby, :is_fired, :job_title, :color,
      :position, :prepayment, :role, :salary_date, :schedule,:store_id, :uniform_sex, :uniform_size, :wish, :wishlist,
      :photo, :photo_cache, :remove_photo, :work_phone, :service_job_sorting_id, :is_senior,
      :dismissed_date, :dismissal_reason_id, :dismissal_comment,

      abilities: [], activities: [],
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
