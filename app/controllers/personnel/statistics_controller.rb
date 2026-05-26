module Personnel
  class StatisticsController < ApplicationController
    def show
      authorize :personnel_statistics, :show?

      @metric  = resolve_metric(params[:metric])
      @month   = resolve_month(params[:month])
      @city    = resolve_city(params[:city_id])
      @cities  = City.all
      @rows    = EmployeeStatisticsQuery.new(metric: @metric, month: @month, city_id: @city.id).call
    end

    private

    def resolve_metric(value)
      User::ACTIVITIES.include?(value.to_s) ? value.to_s : 'long'
    end

    def resolve_month(value)
      Date.parse(value.to_s).beginning_of_month
    rescue ArgumentError, TypeError
      Date.current.beginning_of_month
    end

    def resolve_city(value)
      City.find_by(id: value) || current_user.department&.city || City.first
    end
  end
end
