# frozen_string_literal: true

# rubocop:disable Metrics, Layout/LineLength, Naming/VariableNumber, Style/MultilineBlockChain

ActiveSupport::Dependencies.require_dependency 'kpi_audit/types'

module KpiAudit
  # Applies explainable statistical and behavioral rules to reconstructed visits.
  class Detector
    def initialize(events:, visits:, date_from:, date_to:, mode:, work_days:, configuration: Configuration.load,
                   plans: nil)
      @events = events
      @visits = visits
      @date_from = date_from
      @date_to = date_to
      @mode = mode
      @work_days = work_days
      @config = configuration
      @ignored_city_plans = plans
    end

    def call
      employee_ids.each_with_object({}) { |id, out| out[id] = anomalies_for(id) }
    end

    private

    def employee_ids
      @events.map(&:employee_id).compact.uniq
    end

    def anomalies_for(employee_id)
      events = @events.select { |event| event.employee_id == employee_id }
      anomalies = visit_anomalies(employee_id) + repetition_anomalies(events) + period_anomalies(events)
      threshold = @mode == :strict ? @config.fetch(:strict_output_threshold) : @config.fetch(:output_threshold)
      anomalies.select { |anomaly| anomaly.score >= threshold }
    end

    def visit_anomalies(employee_id)
      @visits.filter_map do |visit|
        events = visit.events.select { |event| event.employee_id == employee_id }
        next if events.size < 2
        next if @mode != :strict && !visit.confirmed? && events.size < 5

        reasons = []
        add_reason(reasons, :multiple_kpi, events.size >= 5 ? :visit_many_kpi : :visit_multiple_kpi,
                   :visit, "#{events.size} KPI в рамках одного восстановленного визита")
        if events.map(&:ticket_id).compact.uniq.one?
          add_reason(reasons, :confirmed_ticket, :confirmed_ticket, :visit,
                     'Один подтверждённый ticket_id')
        end
        burst_reasons(events).each { |reason| reasons << reason }
        anomaly(:multiple_kpi_visit, events, reasons, visit: visit)
      end
    end

    def burst_reasons(events)
      free = events.select { |event| event.kind == :free_job }.sort_by(&:occurred_at)
      return [] if free.size < @config.fetch(:burst, :minimum_count)
      return [] if free.last.occurred_at - free.first.occurred_at > @config.fetch(:burst, :window_minutes).minutes

      key = if free.size >= 20
              :burst_20
            else
              (free.size >= 10 ? :burst_10 : :burst_5)
            end
      reasons = [reason(:burst, key, :burst, "#{free.size} Бесплатных сервисов за #{duration(free)}")]
      intervals = free.each_cons(2).map { |left, right| right.occurred_at - left.occurred_at }
      if median(intervals) < 30
        reasons << reason(:short_intervals, :short_intervals, :burst,
                          'Интервалы операций аномально короткие')
      end
      identical = free.group_by(&:operation_key).values.map(&:size).max.to_i
      if identical >= 5
        reasons << reason(:identical_operations, :identical_operations, :burst,
                          "#{identical} однотипных операций")
      end
      reasons
    end

    def repetition_anomalies(events)
      client = events.group_by(&:client_id).filter_map do |client_id, grouped|
        next unless client_id && confirmed_visit_count(grouped) >= @config.fetch(:repeated_client, :minimum_visits)

        anomaly(:repeated_client, grouped, [reason(:repeated_client, :repeated_client, :repetition,
                                                   "Клиент встречается в #{confirmed_visit_count(grouped)} разных визитах")])
      end
      device = events.group_by do |event|
                 event.serial.presence || event.imei.presence || ("device:#{event.device_id}" if event.device_id)
               end.filter_map do |key, grouped|
        next unless key && (confirmed_visit_count(grouped) >= @config.fetch(:repeated_device,
                                                                            :minimum_visits) || grouped.size >= 2)

        anomaly(:repeated_device, grouped, [reason(:repeated_device, :repeated_device, :repetition,
                                                   "Одно устройство встречается в #{confirmed_visit_count(grouped)} визитах")])
      end
      client + device
    end

    def period_anomalies(events)
      daily = events.group_by { |event| event.occurred_at.to_date }.transform_values(&:size)
      baseline_days = (@date_from..[@date_to - 3.days, @date_from].max).to_a
      baseline = baseline_days.map { |day| daily.fetch(day, 0) }
      ending = ((@date_to - 2.days)..@date_to).sum { |day| daily.fetch(day, 0) }
      expected = median(baseline) * 3
      return [] unless ending >= 5 && ending > [expected * 2, expected + (mad(baseline) * 3)].max

      selected = events.select { |event| event.occurred_at.to_date >= @date_to - 2.days }
      reasons = [reason(:end_of_period, :end_of_period, :period,
                        "В последние 3 дня #{ending} KPI при baseline #{median(baseline).round(2)} KPI/день")]
      long = selected.select { |event| event.kind == :service_job }
      if long.any? && long.count { |event| event.monetary_amount.to_d.zero? }.fdiv(long.size) >= 0.5
        reasons << reason(:no_monetary_result, :no_monetary_result, :economics,
                          'Большинство Длинных приёмок серии без связанной оплаченной продажи')
      end
      [anomaly(:end_of_period, selected, reasons)]
    end

    def anomaly(type, events, reasons, visit: nil)
      score = Scorecard.new(configuration: @config).score(reasons)
      free = events.select { |event| event.kind == :free_job }.sort_by(&:occurred_at)
      intervals = free.each_cons(2).map { |a, b| b.occurred_at - a.occurred_at }
      clients = events.map(&:client).compact.uniq(&:id)
      video = events.map(&:video_diagnostic).compact.find { |item| item[:status] == 'EXACT' }
      Anomaly.new(type: type, score: score, reasons: reasons, events: events,
                  started_at: events.map(&:occurred_at).min, ended_at: events.map(&:occurred_at).max,
                  client: clients.one? ? clients.first : nil,
                  ticket: events.map(&:ticket_id).compact.uniq.one? ? events.map(&:ticket_id).compact.first : nil,
                  window: video&.dig(:called)&.elqueue_window&.window_number,
                  evidence: { visit_confidence: visit&.confidence, visit_evidence: visit&.evidence,
                              count: events.size, intervals_seconds: interval_stats(intervals), urls: events.map(&:url).compact },
                  monetary_result: { amount: events.sum { |event| event.monetary_amount.to_d } },
                  video_context_available: video.present?)
    end

    def confirmed_visit_count(events)
      ids = @visits.select { |visit| (visit.events & events).any? }.map(&:id)
      ids.uniq.size
    end

    def add_reason(list, code, weight, family, text)
      list << reason(code, weight, family, text)
    end

    def reason(code, weight, family, text)
      Reason.new(code: code, text: text, points: @config.fetch(:scoring, weight), family: family)
    end

    def duration(events)
      ActiveSupport::Duration.build(events.last.occurred_at - events.first.occurred_at).inspect
    end

    def median(values)
      return 0.0 if values.empty?

      sorted = values.sort
      sorted.size.odd? ? sorted[sorted.size / 2].to_f : (sorted[sorted.size / 2 - 1] + sorted[sorted.size / 2]).fdiv(2)
    end

    def mad(values)
      center = median(values)
      median(values.map { |value| (value - center).abs })
    end

    def interval_stats(values)
      { min: values.min, max: values.max, mean: values.empty? ? nil : values.sum.fdiv(values.size),
        median: median(values) }
    end
  end
end
# rubocop:enable Metrics, Layout/LineLength, Naming/VariableNumber, Style/MultilineBlockChain
