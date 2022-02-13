# frozen_string_literal: true

class ReportsController < ApplicationController

  INDENT_JOBS = %w[users repair_jobs device_orders orders_statuses technicians_jobs technicians_difficult_jobs
                   repairers sales quick_orders free_jobs users_jobs mac_service].freeze

  before_action -> { authorize :report, :manage? }
  before_action :indent_jobs, only: %i[new create]

  def index
    respond_to do |format|
      format.html
    end
  end

  def new
    @report = build_report
    respond_to do |format|
      format.html
    end
  end

  def create
    @report = build_report
    @report.call
    respond_to do |format|
      format.html { render 'result' }
      format.js { render 'result' }
    end
  end

  private

  def indent_jobs
    @indent_jobs = INDENT_JOBS
    base_name = params[:report][:base_name]
    kind = params[:report][:kind]
    @new_type_report = INDENT_JOBS.include?(base_name) || (base_name == 'few_remnants' && kind == 'spare_parts')
  end

  def build_report
    report_name = params.dig(:report, :base_name)
    report_class_name = "#{report_name.camelize}Report"
    if defined? report_class_name
      klass = report_class_name.constantize
      klass.new params[:report]
    end
  end
end
