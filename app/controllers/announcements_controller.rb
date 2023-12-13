# frozen_string_literal: true

class AnnouncementsController < ApplicationController
  def index
    authorize Announcement

    if params[:actual].present?
      @announcements = policy_scope(current_user.addressed_announcements.active)

      if @announcements.any?
        render @announcements, layout: false
      else
        head :no_content
      end
    else
      @announcements = policy_scope(Announcement).newest.page(params[:page])
    end
  end

  def birthdays
    authorize Announcement, :index?
    @announcements = Announcement.active_birthdays
    head(:no_content) if @announcements.empty?
  end

  def bad_reviews
    authorize Announcement, :index?
    @announcements = Announcement.active_bad_reviews
    head(:no_content) if @announcements.empty?
  end

  def show
    @announcement = find_record(Announcement)

    respond_to do |format|
      format.js
      format.html { redirect_to announcements_path }
    end
  end

  def new
    @announcement = authorize(Announcement.new)

    respond_to do |format|
      format.html
      format.json { render json: @announcement }
    end
  end

  def edit
    @announcement = find_record(Announcement)
  end

  def create
    @announcement = authorize(Announcement.new(announcement_params))

    respond_to do |format|
      if @announcement.save
        format.html { redirect_to announcements_path, notice: t('announcements.created') }
        format.json { render json: @announcement, status: :created, location: @announcement }
      else
        format.html { render action: 'new' }
        format.json { render json: @announcement.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @announcement = find_record(Announcement)

    respond_to do |format|
      if @announcement.update_attributes(announcement_params)
        format.html { redirect_to announcements_path, notice: t('announcements.updated') }
        format.json { render json: @announcement }
        format.js { head :ok }
      else
        format.html { render action: 'edit' }
        format.json { render json: @announcement.errors, status: :unprocessable_entity }
        format.js { head :unprocessable_entity }
      end
    end
  end

  def destroy
    @announcement = find_record(Announcement)
    @announcement.destroy

    respond_to do |format|
      format.html { redirect_to announcements_url }
      format.json { head :no_content }
    end
  end

  def make_announce
    authorize Announcement

    @announcement = if params[:kind] == 'for_coffee'
                      current_user.announcements.create kind: params[:kind], content: params[:content], active: true
                    elsif current_user.announced?
                      nil
                    else
                      current_user.announcements.create(kind: params[:kind],
                                                        active: true)
                    end
  end

  def cancel_announce
    authorize Announcement

    if (@announcements = current_user.announcements.active.where(kind: params[:kind])).any?
      @announcements.find_each do |announcement|
        announcement.update_attributes active: false
      end
    end
  end

  def close
    @announcement = find_record(Announcement)
    @announcement.exclude_recipient current_user
  end

  def close_all
    authorize Announcement
    user_announcements = current_user.addressed_announcements
    @announcement_ids = user_announcements.map(&:id)
    user_announcements.find_each do |announcement|
      announcement.exclude_recipient(current_user)
    end
  end

  def announcement_params
    params.require(:announcement)
          .permit(:active, :content, :department_id, :kind, :user_id)
  end
end