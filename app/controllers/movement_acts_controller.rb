class MovementActsController < ApplicationController
  authorize_resource

  def index
    @movement_acts = MovementAct.search(params).page(params[:page])

    respond_to do |format|
      format.html
      format.js { render 'shared/index' }
      format.json { render json: @movement_acts }
    end
  end

  def show
    @movement_act = MovementAct.find(params[:id])

    respond_to do |format|
      format.html
      format.json { render json: @movement_act }
    end
  end

  def new
    @movement_act = MovementAct.new params[:movement_act]

    respond_to do |format|
      format.html { render 'form' }
      format.json { render json: @movement_act }
    end
  end

  def edit
    @movement_act = MovementAct.find(params[:id])

    respond_to do |format|
      format.html { render 'form' }
      format.json { render json: @movement_act }
    end
  end

  def create
    @movement_act = MovementAct.new(params[:movement_act])

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
    @movement_act = MovementAct.find(params[:id])

    respond_to do |format|
      if @movement_act.update_attributes(params[:movement_act])
        format.html { redirect_to @movement_act, notice: t('movement_acts.updated') }
        format.json { head :no_content }
      else
        format.html { render 'form' }
        format.json { render json: @movement_act.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @movement_act = MovementAct.find(params[:id])
    @movement_act.set_deleted

    respond_to do |format|
      format.html { redirect_to movement_acts_url }
      format.json { head :no_content }
    end
  end

  def post
    @movement_act = MovementAct.find(params[:id])
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
    @movement_act = MovementAct.find(params[:id])
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
    @movement_act = MovementAct.new store_id: current_user.spare_parts_store.id, dst_store_id: current_user.defect_sp_store.id
    respond_to do |format|
      format.html { render 'form' }
    end
  end

end
