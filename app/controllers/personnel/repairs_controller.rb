module Personnel
  class RepairsController < ApplicationController
    def show
      authorize :personnel_repairs, :show?

      @month = resolve_month(params[:month])
      @department = current_user.department
      @rows = TechnicianRepairsQuery.new(department: @department, month: @month).call
    end

    private

    def resolve_month(value)
      Date.parse(value.to_s).beginning_of_month
    rescue ArgumentError, TypeError
      Date.current.beginning_of_month
    end
  end
end
