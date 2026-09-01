# frozen_string_literal: true

module KpiAudit
  # Resolves an investigation's historical queue evidence into one video context.
  # rubocop:disable Metrics
  class VideoSummaryBuilder
    def initialize(events:, investigation_id:, configuration: Configuration.load,
                   camera_catalog: Hikvision::CameraCatalog.new, link_builder: nil)
      @events = events
      @investigation_id = investigation_id
      @configuration = configuration
      @camera_catalog = camera_catalog
      @link_builder = link_builder
    end

    def call
      diagnostic = best_diagnostic
      return unavailable('NO_TICKET', 'Талон электронной очереди не установлен.') unless diagnostic
      return unavailable(diagnostic[:status], explanation_for(diagnostic[:status])) unless routable?(diagnostic)

      build_available(diagnostic)
    rescue Hikvision::CameraCatalog::Error => e
      unavailable('CAMERA_NOT_CONFIGURED', 'Камера для исторического рабочего окна не настроена.',
                  error_class: e.class.name)
    end

    private

    def best_diagnostic
      @events.map { |event| event.video_diagnostic.to_h.symbolize_keys }
             .find { |item| %w[EXACT USER_MISMATCH].include?(item[:status]) } ||
        @events.map { |event| event.video_diagnostic.to_h.symbolize_keys }.find { |item| item[:status].present? }
    end

    def routable?(diagnostic)
      %w[EXACT USER_MISMATCH].include?(diagnostic[:status]) && diagnostic[:waiting_client] && diagnostic[:called]
    end

    def build_available(diagnostic)
      ticket = diagnostic.fetch(:waiting_client)
      called = diagnostic.fetch(:called)
      window = called.elqueue_window
      return unavailable('NO_WINDOW', 'Историческое рабочее окно не установлено.') unless window

      queue = ticket.electronic_queue
      route = Hikvision::CameraRouter.for(queue: queue.ipad_link, window: window.window_number,
                                          configuration: @camera_catalog)
      primary = camera(route.nvr_name, route.primary)
      start_time, end_time, segments = video_range
      payload = safe_payload(ticket, route, primary, start_time, end_time, segments)
      primary_link = link(route.primary, primary, payload) if @link_builder
      alternatives = if @link_builder
                       route.fallback.map do |key|
                         metadata = camera(route.nvr_name, key)
                         link(key, metadata, payload.merge(camera_key: key.to_s, channel: metadata.channel))
                       end
                     else
                       []
                     end
      mismatch = diagnostic[:status] == 'USER_MISMATCH'
      VideoSummary.new(
        available: true, playback_available: true, status: diagnostic[:status],
        explanation: available_explanation(mismatch, primary_link),
        queue_name: queue.name, queue_key: queue.ipad_link, ticket_id: ticket.id,
        ticket_number: ticket.ticket_number, window_number: window.window_number,
        camera_name: primary.name, camera_key: route.primary, channel: primary.channel,
        fallback_cameras: route.fallback, range_start: start_time, range_end: end_time,
        confidence_score: mismatch ? 70 : 100, confidence_reasons: confidence_reasons(mismatch),
        primary_link: primary_link, alternative_links: alternatives,
        diagnostics: { employee_mismatch: mismatch, segmented: segments.size > 1, segments: segments,
                       nvr_name: route.nvr_name }
      )
    end

    def video_range
      times = @events.map(&:occurred_at).compact.sort
      raise ArgumentError, 'video events have no timestamps' if times.empty?

      start_time = times.first - video_config(:pre_roll_seconds).seconds
      end_time = times.last + video_config(:post_roll_seconds).seconds
      max = video_config(:max_preview_duration_seconds).seconds
      segments = []
      cursor = start_time
      while cursor < end_time
        segment_end = [cursor + max, end_time].min
        segments << { start_time: cursor, end_time: segment_end }
        cursor = segment_end
      end
      [start_time, end_time, segments]
    end

    def camera(nvr_name, key)
      @camera_catalog.camera(nvr_name, key)
    end

    def link(key, metadata, payload)
      VideoLink.new(type: :ais_video, url: @link_builder.call(payload.merge(camera_key: key.to_s,
                                                                            channel: metadata.channel)),
                    camera_name: metadata.name, channel: metadata.channel,
                    start_time: payload[:range_start], end_time: payload[:range_end])
    end

    def safe_payload(ticket, route, camera_metadata, start_time, end_time, segments)
      { investigation_id: @investigation_id, ticket_id: ticket.id, queue_key: route.queue_key,
        ticket_number: ticket.ticket_number, camera_name: camera_metadata.name,
        window_number: route.window, nvr_name: route.nvr_name, camera_key: route.primary.to_s,
        channel: camera_metadata.channel, range_start: start_time.iso8601,
        range_end: end_time.iso8601,
        segments: segments.map { |item| item.transform_values(&:iso8601) } }
    end

    def video_config(key)
      @configuration.fetch(:video, key)
    end

    def confidence_reasons(mismatch)
      reasons = ['Подтверждён талон электронной очереди.', 'Установлено историческое рабочее окно.',
                 'Камера определена по маршрутизации рабочего окна.']
      reasons << 'Талон вызван другим сотрудником; видео определено по талону и рабочему окну.' if mismatch
      reasons
    end

    def available_explanation(mismatch, primary_link)
      base = if mismatch
               'Талон вызван другим сотрудником. Видео определено по талону и рабочему окну, а не по владельцу KPI.'
             else
               'Видео-контекст определён по талону и историческому рабочему окну.'
             end
      return base if primary_link

      "#{base} Пользовательская ссылка не опубликована."
    end

    def explanation_for(status)
      { 'NO_TICKET' => 'Талон электронной очереди не установлен.',
        'NO_CALLED' => 'Историческое рабочее окно не установлено.',
        'NO_WINDOW' => 'Историческое рабочее окно не установлено.',
        'UNSUPPORTED_QUEUE' => 'Для очереди не настроена камера.' }.fetch(status, 'Видео-контекст не установлен.')
    end

    def unavailable(status, explanation, diagnostics = {})
      VideoSummary.new(available: false, playback_available: false, status: status, explanation: explanation,
                       confidence_score: 0, confidence_reasons: [], primary_link: nil,
                       alternative_links: [], diagnostics: diagnostics)
    end
  end
  # rubocop:enable Metrics
end
