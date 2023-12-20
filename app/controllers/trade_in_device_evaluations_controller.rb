class TradeInDeviceEvaluationsController < ApplicationController
  before_action :set_product_groups, only: %i[new edit create update]

  def index
    authorize TradeInDeviceEvaluation
    @trade_in_device_evaluations = TradeInDeviceEvaluation.all
  end

  def new
    authorize TradeInDeviceEvaluation
    @trade_in_device_evaluation = TradeInDeviceEvaluation.new

    respond_to do |format|
      format.js { render 'shared/show_secondary_form' }
    end
  end

  def create
    authorize TradeInDeviceEvaluation

    name = TradeInDeviceEvaluation.construct_name(trade_in_device_evaluation_params[:product_group_id],
      option_ids_params)
    @trade_in_device_evaluation = TradeInDeviceEvaluation.new(trade_in_device_evaluation_params
      .except(:option_ids)
      .merge(name: name))

    respond_to do |format|
      if @trade_in_device_evaluation.save
        @trade_in_device_evaluations = TradeInDeviceEvaluation.all
        format.js { render 'save' }
      else
        format.js { render 'shared/show_secondary_form' }
      end
    end
  end

  def bulk_update
    begin
      authorize TradeInDeviceEvaluation

      trade_in_device_evaluation_params_list = evaluation_list_params

      trade_in_device_evaluation_params_list.values.each do |trade_in_device_evaluation_params|
        trade_in_device_evaluation = TradeInDeviceEvaluation.find(trade_in_device_evaluation_params[:id])
        trade_in_device_evaluation.update(trade_in_device_evaluation_params.except(:id))
      end

      @trade_in_device_evaluations = TradeInDeviceEvaluation.all
      respond_to do |format|
        format.js { render 'save' }
      end
    rescue ActiveRecord::RecordInvalid => e
      respond_to do |format|
        format.js { render json: { error: e.message }, status: :unprocessable_entity }
      end
      flash[:error] = "Ошибка. #{e.message}"
    end
  end

  def destroy
    @trade_in_device_evaluation = find_record TradeInDeviceEvaluation
    @trade_in_device_evaluation.destroy
    @trade_in_device_evaluations = TradeInDeviceEvaluation.all

    respond_to do |format|
      format.js { render 'save' }
    end
  end

  private
    def set_product_groups
      @product_groups = ProductGroup.available_for_trade_in.arrange_as_array({order: 'position'})
    end

    def option_ids_params
      params.permit(option_ids: [])[:option_ids].reject(&:blank?)
    end

    def evaluation_list_params
      params.permit(evaluation_list: [:id, :product_group_id, :min_value, :max_value, :lack_of_kit, :name])[:evaluation_list]
    end

    def trade_in_device_evaluation_params
      params.require(:trade_in_device_evaluation)
            .permit(:product_group_id, :min_value, :max_value, :lack_of_kit, option_ids: [])
    end
end