# frozen_string_literal: true

class RevaluationActsController < ApplicationController
  def index
    authorize RevaluationAct
    @revaluation_acts = policy_scope(RevaluationAct).search(params).page(params[:page])

    respond_to do |format|
      format.html
      format.js { render 'shared/index' }
      format.json { render json: @revaluation_acts }
    end
  end

  def show
    @revaluation_act = find_record RevaluationAct
    respond_to do |format|
      format.html
      format.json { render json: @revaluation_act }
    end
  end

  def new
    @revaluation_act = authorize RevaluationAct.new(revaluation_act_params)
    respond_to do |format|
      format.html { render 'form' }
      format.json { render json: @revaluation_act }
    end
  end

  def edit
    @revaluation_act = find_record RevaluationAct
    respond_to do |format|
      format.html { render 'form' }
      format.json { render json: @revaluation_act }
    end
  end

  def create
    @revaluation_act = authorize RevaluationAct.new(revaluation_act_params)
    respond_to do |format|
      if @revaluation_act.save
        format.html { redirect_to @revaluation_act, notice: t('revaluation_acts.created') }
        format.json { render json: @revaluation_act, status: :created, location: @revaluation_act }
      else
        format.html { render 'form' }
        format.json { render json: @revaluation_act.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @revaluation_act = find_record RevaluationAct
    respond_to do |format|
      if @revaluation_act.update_attributes(revaluation_act_params)
        format.html { redirect_to @revaluation_act, notice: t('revaluation_acts.updated') }
        format.json { head :no_content }
      else
        format.html { render 'form' }
        format.json { render json: @revaluation_act.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @revaluation_act = find_record RevaluationAct
    @revaluation_act.destroy
    respond_to do |format|
      format.html { redirect_to revaluation_acts_url }
      format.json { head :no_content }
    end
  end

  def post
    @revaluation_act = find_record RevaluationAct
    respond_to do |format|
      if @revaluation_act.post
        format.html { redirect_to @revaluation_act, notice: t('documents.posted') }
      else
        flash.alert = @revaluation_act.errors.full_messages
        format.html { redirect_to @revaluation_act, error: t('documents.not_posted') }
      end
    end
  end

  def unpost
    @revaluation_act = find_record RevaluationAct
    respond_to do |format|
      if @revaluation_act.unpost
        format.html { redirect_to @revaluation_act, notice: t('documents.unposted') }
      else
        flash.alert = @revaluation_act.errors.full_messages
        format.html { redirect_to @revaluation_act, error: t('documents.not_unposted') }
      end
    end
  end

  def revaluation_act_params
    params.require(:revaluation_act)
          .permit(:date, :price_type_id, :status,
                  revaluations: [:price, :product_id, :revaluation_act_id]

          )
    # TODO: check nested attributes for: revaluations
  end
end
