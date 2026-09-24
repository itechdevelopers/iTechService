require 'csv'

class WeeklyMarkupDashboardsController < ApplicationController
  before_action :authorize_dashboard
  before_action :set_period, only: %i[details branch download]

  def show
    @yearly_markup_summary = WeeklyMarkup::YearSummary.new.call
    @iphone_sales = IphoneSales::Dashboard.new.call
    @receipt_counts = ActivityCounts::Dashboard.new(metric: 'receipts').call
    @repair_counts = ActivityCounts::Dashboard.new(metric: 'issued_repairs').call
  end

  def activity_counts
    year = params[:year].present? ? Integer(params[:year]) : Time.current.in_time_zone('Asia/Vladivostok').year
    @activity_counts = ActivityCounts::Dashboard.new(metric: params[:metric].to_s, year: year, branch_id: params[:branch_id]).call
  rescue ArgumentError
    redirect_to weekly_markup_dashboard_path, alert: 'Некорректный показатель, год или магазин.'
  end

  def iphone_sales
    year = params[:year].present? ? Integer(params[:year]) : Time.current.in_time_zone('Asia/Vladivostok').year
    raise ArgumentError unless year.between?(2019, Time.current.in_time_zone('Asia/Vladivostok').year)
    @iphone_sales = IphoneSales::Dashboard.new(year: year, warehouse_id: params[:warehouse_id]).call
  rescue ArgumentError
    redirect_to iphone_sales_weekly_markup_dashboard_path, alert: 'Некорректный год или филиал.'
  end

  def details
    @dashboard = dashboard_data
  end

  def branch
    @dashboard = dashboard_data
    @branch = @dashboard[:branches].find { |item| item[:warehouse_id] == params[:warehouse_id].to_s }
    raise ActiveRecord::RecordNotFound unless @branch
  end

  def download
    data = dashboard_data
    if params[:format] == 'csv'
      send_data build_csv(data), filename: "weekly-markup-#{@period_from}-#{@period_to}.csv", type: 'text/csv; charset=utf-8'
    else
      send_data JSON.pretty_generate(json_payload(data)), filename: "weekly-markup-#{@period_from}-#{@period_to}.json", type: 'application/json'
    end
  end

  private

  def authorize_dashboard
    authorize :weekly_markup_dashboard, "#{action_name}?"
  end

  def set_period
    latest = WeeklyMarkupImport.successful.newest_first.first
    default_to = latest&.period_to || Date.current
    default_from = [latest&.period_from || default_to - 30.days, default_to - 30.days].max
    @period_from = params[:from].present? ? Date.iso8601(params[:from]) : default_from
    @period_to = params[:to].present? ? Date.iso8601(params[:to]) : default_to
    raise ArgumentError, 'Некорректный период' if @period_to < @period_from || (@period_to - @period_from).to_i > 366
  rescue ArgumentError
    redirect_to details_weekly_markup_dashboard_path, alert: 'Некорректный период.'
  end

  def dashboard_data
    @dashboard_data ||= WeeklyMarkup::DashboardData.new(from: @period_from, to: @period_to).call
  end

  def build_csv(data)
    CSV.generate(headers: true) do |csv|
      csv << %w[Дата Филиал Выручка_регистра Исключенные_операции Выручка_в_расчете Себестоимость Прибыль_до_налога Налог_с_безналичных Прибыль_после_налога Наценка_до_налога Наценка_после_налога Наличные Безналичные Не_распределено]
      data[:branches].each do |branch|
        branch[:days].each do |day|
          csv << [day[:date], branch[:name], day[:source_revenue].to_s('F'), day[:excluded_operations_amount].to_s('F'),
                  *%i[revenue cost gross_profit_before_tax noncash_tax gross_profit markup_before_tax markup cash noncash unallocated].map do |key|
                    value = day[key]
                    value.nil? ? nil : value.to_s('F')
                  end]
        end
      end
    end
  end

  def json_payload(value)
    case value
    when Hash
      value.each_with_object({}) { |(key, item), result| result[key] = json_payload(item) }
    when Array
      value.map { |item| json_payload(item) }
    when BigDecimal
      value.to_s('F')
    else
      value
    end
  end
end
