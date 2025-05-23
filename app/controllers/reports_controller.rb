# frozen_string_literal: true

class ReportsController < ApplicationController

  INDENT_JOBS = %w[users repair_jobs device_orders orders_statuses technicians_jobs technicians_difficult_jobs
                   repairers sales quick_orders free_jobs users_jobs mac_service warranty_repair_parts margin
                   body_repair_jobs repair_parts done_tasks done_tasks_copy contractors_defected_spare_parts
                   defected_spare_parts spare_part_movements client_reviews repeated_repair].freeze

  BOOTSTRAP4 = %w[done_tasks_copy]

  before_action -> { authorize :report, :manage? }
  before_action :indent_jobs, only: %i[new create]
  before_action :set_bootstrap_version, except: :index
  before_action :create_report, only: %i[create]

  def index
    @reports_board = ReportsBoard.find_by(name: 'Default')
    respond_to do |format|
      format.html
    end
  end

  def new
    @report = build_report
    @report_annotation = get_annotation
    respond_to do |format|
      format.html
    end
  end

  def create
    respond_to do |format|
      format.html do
        if params[:report][:format] == 'xlsx'
          export_report
        else
          render 'result'
        end
      end
      format.js { render 'result' }
    end
  end

  private

  def get_annotation
    if params[:report][:kind]
      ReportCard.find_by(content: "#{params[:report][:base_name]}_#{params[:report][:kind]}").annotation
    else
      ReportCard.find_by(content: params[:report][:base_name]).annotation
    end
  end

  def export_report
    p = Axlsx::Package.new
    wb = p.workbook
    @report.to_xlsx(wb)
    send_data p.to_stream.read,
              filename: "#{@report.name}_#{Time.current.strftime('%Y%m%d_%H%M')}.xlsx",
              type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
  end

  def create_report
    @report = build_report
    @report.call
  end

  def set_bootstrap_version
    @new_type_report ||= false
    base_name = params[:report][:base_name]
    if @new_type_report || BOOTSTRAP4.include?(base_name)
      @bootstrap_ver = 4
    else
      @bootstrap_ver = 3
    end
  end

  def indent_jobs
    @indent_jobs ||= INDENT_JOBS
    base_name = params[:report][:base_name]
    kind = params[:report][:kind]
    @new_type_report ||= INDENT_JOBS.include?(base_name) || (base_name == 'few_remnants' && kind == 'spare_parts')
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
