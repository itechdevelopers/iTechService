class UsersController < ApplicationController
  before_action :load_infos, only: [:show, :profile]

  def index
    authorize User
    @users = policy_scope(User).search(params).id_asc.page(params[:page]).per(50)

    respond_to do |format|
      format.html
      format.json { render json: {users: @users.map { |u| u.short_name }} }
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
    @user = authorize User.new(params[:user])

    respond_to do |format|
      if @user.save
        format.html { redirect_to @user, notice: t('users.created') }
        format.json { render json: @user, status: :created, location: @user }
      else
        format.html { render 'form' }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @user = find_record User

    if params[:user][:password].blank?
      params[:user].delete(:password)
      params[:user].delete(:password_confirmation)
    end

    params[:user].delete :hiring_date

    respond_to do |format|
      if @user.update_attributes(params[:user])
        format.html { redirect_to @user, notice: t('users.updated') }
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
        format.json { render json: {wish: @user.wish} }
      else
        format.json { render json: {error: 'error'}}
      end
    end
  end

  def schedule
    authorize User
    @users = User.active.schedulable.id_asc
    @locations = Location.for_schedule
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
    @duty_day = authorize DutyDay.new(params[:duty_day])
    @duty_day.save
    @day = @duty_day.day
    @kind = @duty_day.kind
    render 'update_duty_day'
  end

  def destroy_duty_day
    duty_day = authorize DutyDay.find(params[:duty_day_id])
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

  private

  def load_infos
    # @infos = Info.actual.available_for(current_user).grouped_by_date.limit 20
    @infos = policy_scope(Info).actual.available_for(current_user).newest.limit(20)
  end
end
