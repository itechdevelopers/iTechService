# frozen_string_literal: true

class MovementActsController < ApplicationController
  helper_method :sort_column, :sort_direction

  def index
    authorize MovementAct
    @movement_acts = policy_scope(MovementAct).search(search_params).page(params[:page])

    @movement_acts = if params.key?(:sort) && params.key?(:direction)
                       @movement_acts.order("movement_acts.#{sort_column} #{sort_direction}")
                     else
                       @movement_acts.order(date: :desc)
                     end

    @movement_acts = @movement_acts.page(params[:page])

    respond_to do |format|
      format.html
      format.js { render 'shared/index' }
      format.json { render json: @movement_acts }
    end
  end

  def show
    @movement_act = find_record MovementAct

    respond_to do |format|
      format.html
      format.json { render json: @movement_act }
    end
  end

  def new
    @movement_act = authorize MovementAct.new

    respond_to do |format|
      format.html { render 'form' }
      format.json { render json: @movement_act }
    end
  end

  def edit
    @movement_act = find_record MovementAct

    respond_to do |format|
      format.html { render 'form' }
      format.json { render json: @movement_act }
    end
  end

  def create
    @movement_act = authorize MovementAct.new(movement_act_params)

    respond_to do |format|
      if @movement_act.save
        format.html { redirect_to @movement_act, notice: t('movement_acts.created') }
        format.json { render json: @movement_act, status: :created, location: @movement_act }
      else
        format.html { render 'form' }
        format.json { render json: @movement_act.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @movement_act = find_record MovementAct

    respond_to do |format|
      if @movement_act.update_attributes(movement_act_params)
        format.html { redirect_to @movement_act, notice: t('movement_acts.updated') }
        format.json { head :no_content }
      else
        format.html { render 'form' }
        format.json { render json: @movement_act.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @movement_act = find_record MovementAct
    @movement_act.set_deleted

    respond_to do |format|
      format.html { redirect_to movement_acts_url }
      format.json { head :no_content }
    end
  end

  def post
    @movement_act = find_record MovementAct
    respond_to do |format|
      if @movement_act.post
        format.html { redirect_to @movement_act, notice: t('documents.posted') }
      else
        flash.alert = @movement_act.errors.full_messages
        format.html { redirect_to @movement_act, error: t('documents.not_posted') }
      end
    end
  end

  def unpost
    @movement_act = find_record MovementAct
    respond_to do |format|
      if @movement_act.unpost
        format.html { redirect_to @movement_act, notice: t('documents.unposted') }
      else
        flash.alert = @movement_act.errors.full_messages
        format.html { redirect_to @movement_act, error: t('documents.not_unposted') }
      end
    end
  end

  def make_defect_sp
    @movement_act = authorize MovementAct.new(store_id: current_user.spare_parts_store.id,
                                              dst_store_id: current_user.defect_sp_store.id)

    respond_to do |format|
      format.html { render 'form' }
    end
  end

  private

  def sort_column
    MovementAct.column_names.include?(params[:sort]) ? params[:sort] : ''
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : ''
  end

  def movement_act_params
    params.require(:movement_act).permit(
      :date, :dst_store_id, :store_id, :user_id, :comment,
      movement_items_attributes: [:id, :_destroy, :item_id, :quantity]
    )
  end
end
