# frozen_string_literal: true

class InfosController < ApplicationController
  helper_method :sort_column, :sort_direction

  def index
    authorize Info

    if params[:important].present?
      @info = policy_scope(Info).actual.important.first

      if @info.present?
        render @info, layout: false
      else
        render nothing: true
      end
    elsif params[:personal].present?
      if (@infos = Info.actual.addressed_to(current_user)).present?
        render @infos, layout: false
      else
        render nothing: true
      end
    else
      @infos = params[:archive].present? ? policy_scope(Info).archived.newest : policy_scope(Info).actual.newest
      if policy(Info).manage?
        @infos = @infos.newest
        @infos = @infos.reorder("#{sort_column} #{sort_direction}") unless sort_column.blank? && sort_direction.blank?
      else
        @infos = @infos.newest.available_for(current_user)
      end
      @infos = @infos.page(params[:page])

      respond_to do |format|
        format.html
        format.json { render json: @infos }
        format.js { render 'shared/index' }
      end
    end
  end

  def show
    @info = find_record Info

    respond_to do |format|
      format.html
      format.json { render json: @info }
    end
  end

  def new
    @info = authorize Info.new

    respond_to do |format|
      format.html
      format.json { render json: @info }
    end
  end

  def edit
    @info = find_record Info
  end

  def create
    @info = authorize Info.new(info_params)

    respond_to do |format|
      if @info.save
        format.html { redirect_to @info, notice: t('infos.created') }
        format.json { render json: @info, status: :created, location: @info }
      else
        format.html { render action: 'new' }
        format.json { render json: @info.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @info = find_record Info

    respond_to do |format|
      if @info.update_attributes(params[:info])
        format.html { redirect_to @info, notice: t('infos.updated') }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @info.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @info = find_record Info
    @info.destroy

    respond_to do |format|
      format.html { redirect_to infos_url }
      format.json { head :no_content }
    end
  end

  private

  def sort_column
    Info.column_names.include?(params[:sort]) ? params[:sort] : ''
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : ''
  end

  def info_params
    params.require(:info)
          .permit(:content, :department_id, :important, :is_archived, :recipient_id, :title,
                  comment: [:content, :commentable_id, :commentable_type],
                  comments: [[:content, :commentable_id, :commentable_type]]
          )
    # TODO: check nested attributes for: comments
  end
end
