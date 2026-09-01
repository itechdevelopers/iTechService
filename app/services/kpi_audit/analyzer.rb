# frozen_string_literal: true

# rubocop:disable Metrics, Style/MultilineBlockChain

ActiveSupport::Dependencies.require_dependency 'kpi_audit/types'

module KpiAudit
  # Read-only orchestration entry point for one department and reporting period.
  class Analyzer
    MODES = %i[normal strict].freeze

    def self.call(**options)
      new(**options).call
    end

    def self.for_month(department_id:, year:, month:, mode: :normal, **options)
      date = Date.new(Integer(year), Integer(month), 1)
      call(department_id: department_id, date_from: date, date_to: date.end_of_month, mode: mode, **options)
    end

    def initialize(department_id:, date_from:, date_to:, mode: :normal, configuration: Configuration.load,
                   collector_class: Collector)
      @department = Department.find(department_id)
      @date_from = date_from.to_date
      @date_to = date_to.to_date
      @mode = mode.to_sym
      @configuration = configuration
      @collector_class = collector_class
      validate!
    end

    def call
      analyze
    end

    private

    def analyze
      events = @collector_class.new(department: @department, date_from: @date_from, date_to: @date_to).call
      visits = VisitReconstructor.new(events: events, configuration: @configuration).call
      users = User.where(id: events.map(&:employee_id).compact.uniq).index_by(&:id)
      work_days = work_days_for(users.keys)
      detector = Detector.new(events: events, visits: visits, date_from: @date_from, date_to: @date_to,
                              mode: @mode, work_days: work_days, configuration: @configuration)
      anomalies = detector.call
      scorecard = Scorecard.new(configuration: @configuration)
      employees = users.map do |id, user|
        user_events = events.select { |event| event.employee_id == id }
        user_anomalies = anomalies.fetch(id, [])
        score = scorecard.score(user_anomalies.flat_map(&:reasons).uniq(&:code))
        EmployeeResult.new(id: id, full_name: user.full_name, login: user.username,
                           risk_score: score, risk_level: scorecard.level(score), anomalies: user_anomalies,
                           statistics: employee_statistics(user_events, user_anomalies, work_days[id]))
      end.sort_by { |employee| -employee.risk_score }
      investigations = build_investigations(employees)
      @analysis = Analysis.new(department: @department, date_from: @date_from, date_to: @date_to, mode: @mode,
                               employees: employees, investigations: investigations,
                               statistics: analysis_statistics(events, visits, employees),
                               metadata: { read_only: true, generated_at: Time.current, kpi_dates: official_kpi_dates })
    end

    def analysis_statistics(events, visits, employees)
      { kpi_events: events.size, visits: visits.size, employees_analyzed: employees.size,
        review_candidates: employees.count { |item| item.anomalies.any? } }
    end

    def build_investigations(employees)
      generated_at = Time.current
      employees.flat_map do |employee|
        employee.anomalies.map do |anomaly|
          id = InvestigationCase.id_for(employee.id, anomaly)
          video = VideoSummaryBuilder.new(events: anomaly.events, investigation_id: id,
                                          configuration: @configuration).call
          InvestigationCase.build(id: id, employee: employee, anomaly: anomaly, video_summary: video,
                                  configuration: @configuration, generated_at: generated_at)
        end
      end
    end

    def work_days_for(user_ids)
      TimesheetDay.work.where(user_id: user_ids, date: @date_from..@date_to)
                  .group(:user_id).count
    end

    def employee_statistics(events, anomalies, work_days)
      long = events.select { |event| event.kind == :service_job }
      {
        service_jobs: long.size, free_jobs: events.count { |event| event.kind == :free_job },
        mac: events.count { |event| event.kind == :mac }, anomalies: anomalies.size,
        repeated_clients: anomalies.count { |item| item.type == :repeated_client },
        kpi_without_result: long.count { |event| event.monetary_amount.to_d.zero? },
        monetary_conversion: if long.empty?
                               nil
                             else
                               long.count do |event|
                                 event.monetary_amount.to_d.positive?
                               end.fdiv(long.size)
                             end,
        monetary_amount: long.sum { |event| event.monetary_amount.to_d },
        work_days: work_days.presence || events.map { |event| event.occurred_at.to_date }.uniq.size,
        work_days_source: work_days.present? ? :timesheet : :observed_kpi_days,
        end_of_period: anomalies.any? { |item| item.type == :end_of_period }
      }
    end

    def official_kpi_dates
      { service_job: :created_at, free_job: :performed_at, mac: :done_at }
    end

    def validate!
      raise ArgumentError, "unknown mode #{@mode.inspect}" unless MODES.include?(@mode)
      raise ArgumentError, 'date_from must be on or before date_to' if @date_from > @date_to
      raise ArgumentError, 'analysis period must not exceed 366 days' if (@date_to - @date_from).to_i > 366
    end
  end
end
# rubocop:enable Metrics, Style/MultilineBlockChain
