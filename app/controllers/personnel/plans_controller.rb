module Personnel
  class PlansController < ApplicationController
    def update
      authorize Plan, :update?

      @plan = Plan.find_or_initialize_by(
        month:    parsed_month,
        city_id:  params[:city_id],
        metric:   params[:metric]
      )
      @plan.target = params[:target]

      if @plan.save
        render json: { target: @plan.target }, status: :ok
      else
        render json: { errors: @plan.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def parsed_month
      Date.parse(params[:month].to_s).beginning_of_month
    rescue ArgumentError, TypeError
      Date.current.beginning_of_month
    end
  end
end
