# frozen_string_literal: true

class DeductionActsController < ApplicationController
  helper_method :sort_column, :sort_direction

  def index
    authorize DeductionAct
    @deduction_acts = policy_scope(DeductionAct).search(params)

    @deduction_acts = if params.key?(:sort) && params.key?(:direction)
                        @deduction_acts.order("deduction_acts.#{sort_column} #{sort_direction}")
                      else
                        @deduction_acts.order(date: :desc)
                      end

    @deduction_acts = @deduction_acts.page(params[:page])

    respond_to do |format|
      format.html # index.html.erb
      format.js { render 'shared/index' }
      format.json { render json: @deduction_acts }
    end
  end

  def show
    @deduction_act = find_record DeductionAct

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @deduction_act }
    end
  end

  def new
    @deduction_act = authorize DeductionAct.new

    respond_to do |format|
      format.html { render 'form' }
      format.json { render json: @deduction_act }
    end
  end

  def edit
    @deduction_act = find_record DeductionAct

    respond_to do |format|
      format.html { render 'form' }
      format.json { render json: @deduction_act }
    end
  end

  def create
    @deduction_act = authorize DeductionAct.new(deduction_act_params)

    respond_to do |format|
      if @deduction_act.save
        format.html { redirect_to @deduction_act, notice: t('deduction_acts.created') }
        format.json { render json: @deduction_act, status: :created, location: @deduction_act }
      else
        format.html { render 'form' }
        format.json { render json: @deduction_act.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @deduction_act = find_record DeductionAct

    respond_to do |format|
      if @deduction_act.update_attributes(deduction_act_params)
        format.html { redirect_to @deduction_act, notice: t('deduction_acts.updated') }
        format.json { head :no_content }
      else
        format.html { render 'form' }
        format.json { render json: @deduction_act.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @deduction_act = find_record DeductionAct
    @deduction_act.destroy

    respond_to do |format|
      format.html { redirect_to deduction_acts_url }
      format.json { head :no_content }
    end
  end

  def post
    @deduction_act = find_record DeductionAct

    respond_to do |format|
      if @deduction_act.post
        DocumentMailer.deduction_notification(@deduction_act.id).deliver_later
        format.html { redirect_to @deduction_act, notice: t('documents.posted') }
      else
        flash.alert = @deduction_act.errors.full_messages
        format.html { redirect_to @deduction_act, error: t('documents.not_posted') }
      end
    end
  end

  private

  def sort_column
    DeductionAct.column_names.include?(params[:sort]) ? params[:sort] : ''
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : ''
  end

  def deduction_act_params
    params.require(:deduction_act)
          .permit(:comment, :date, :status, :store_id, :user_id,
                  deduction_items: [:quantity, :item_id])
    # :deduction_items_attributes
    # TODO: check nested attributes for: deduction_items
  end
end
