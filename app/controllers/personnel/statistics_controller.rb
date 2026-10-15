module Personnel
  class StatisticsController < ApplicationController
    def show
      authorize :personnel_statistics, :show?

      @metric  = resolve_metric(params[:metric])
      @month   = resolve_month(params[:month])
      @city    = resolve_city(params[:city_id])
      @cities  = City.all
      @departments = Department.where(city_id: @city.id).order(:name)
      if @metric == 'reviews'
        @department = @departments.find_by(id: params[:department_id])
        @from_date, @to_date = review_period
      end
      @rows    = EmployeeStatisticsQuery.new(metric: @metric, month: @month, city_id: @city.id,
                                           department_id: @department&.id, from_date: @from_date, to_date: @to_date).call
      @show_plan = @department.nil? && (@from_date.nil? || (@from_date == @month && @to_date == @month.end_of_month))
      @plan    = Plan.find_or_initialize_by(month: @month, city_id: @city.id, metric: @metric)
    end

    private

    def review_period
      return [@month, @month.end_of_month] if params[:from_date].blank? && params[:to_date].blank?
      first = params[:from_date].present? ? Date.iso8601(params[:from_date]) : @month
      last = params[:to_date].present? ? Date.iso8601(params[:to_date]) : @month.end_of_month
      raise ArgumentError unless (1..9999).cover?(first.year) && (1..9999).cover?(last.year)
      raise ArgumentError if first > last || (last - first) > 365
      [first, last]
    rescue ArgumentError, TypeError
      flash.now[:alert] = I18n.t('personnel.statistics.show.invalid_period')
      [@month, @month.end_of_month]
    end

    def resolve_metric(value)
      User::STATISTICS_ACTIVITIES.include?(value.to_s) ? value.to_s : 'long'
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
