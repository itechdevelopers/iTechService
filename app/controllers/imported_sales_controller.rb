# frozen_string_literal: true

class ImportedSalesController < ApplicationController
  def index
    authorize ImportedSale
    @imported_sales = policy_scope(ImportedSale).search(search_params).order('sold_at desc').page(params[:page])

    respond_to do |format|
      format.html # index.html.erb
      format.js { render 'shared/index' }
      format.json { render json: @imported_sales.any? ? @imported_sales : { message: t('devices.not_found') } }
    end
  end

  def imported_sale_params
    params.require(:imported_sale)
          .permit(:device_type_id, :imei, :quantity, :serial_number, :sold_at)
  end
end
