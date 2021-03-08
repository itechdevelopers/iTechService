# frozen_string_literal: true

class OptionValuesController < ApplicationController
  def index
    authorize OptionValue
    product_group = ProductGroup.find(params[:product_type_id])
    @option_values = product_group.option_values.ordered
  end

  def option_value_params
    params.require(:option_value)
          .permit(:code, :name, :option_type_id, :position)
  end
end
