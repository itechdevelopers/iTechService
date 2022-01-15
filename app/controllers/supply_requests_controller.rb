# frozen_string_literal: true

class SupplyRequestsController < ApplicationController
  helper_method :sort_column, :sort_direction

  def index
    authorize SupplyRequest
    @supply_requests = policy_scope(SupplyRequest).search(action_params).created_desc.page(params[:page])

    respond_to do |format|
      format.html
      format.js
    end
  end

  def show
    @supply_request = find_record SupplyRequest

    respond_to do |format|
      format.html
    end
  end

  def new
    @supply_request = authorize SupplyRequest.new

    respond_to do |format|
      format.html { render 'form' }
    end
  end

  def edit
    @supply_request = find_record SupplyRequest

    respond_to do |format|
      format.html { render 'form' }
    end
  end

  def create
    @supply_request = authorize SupplyRequest.new(supply_request_params)

    respond_to do |format|
      if @supply_request.save
        format.html { redirect_to supply_requests_path, notice: t('supply_requests.created') }
        format.json { render json: @supply_request, status: :created, location: @supply_request }
      else
        format.html { render 'form' }
        format.json { render json: @supply_request.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @supply_request = find_record SupplyRequest

    respond_to do |format|
      if @supply_request.update_attributes(supply_request_params)
        format.html { redirect_to supply_requests_path, notice: t('supply_requests.updated') }
      else
        format.html { render 'form' }
      end
    end
  end

  def destroy
    @supply_request = find_record SupplyRequest
    @supply_request.destroy

    respond_to do |format|
      format.html { redirect_to supply_requests_url }
      format.json { head :no_content }
    end
  end

  def make_done
    @supply_request = find_record SupplyRequest
    respond_to do |format|
      if @supply_request.update_attributes(status: 'done')
        format.html { redirect_to supply_requests_path, notice: t('supply_requests.updated') }
      else
        format.html { render 'form' }
      end
    end
  end

  def make_new
    @supply_request = find_record SupplyRequest
    respond_to do |format|
      if @supply_request.update_attributes(status: 'new')
        format.html { redirect_to supply_requests_path, notice: t('supply_requests.updated') }
      else
        format.html { render 'form' }
      end
    end
  end

  private

  def sort_column
    Order.column_names.include?(params[:sort]) ? params[:sort] : ''
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : ''
  end

  def supply_request_params
    params.require(:supply_request)
          .permit(:department_id, :description, :object, :status, :user_id)
  end
end
