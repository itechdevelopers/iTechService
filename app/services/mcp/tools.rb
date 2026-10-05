# frozen_string_literal: true
require 'digest'
require 'json'

module Mcp
  class Tools
    class Error < StandardError
      attr_reader :code
      def initialize(code, message)
        @code = code
        super(message)
      end
    end
    READ_TOOLS = %w[search_orders get_order get_order_statuses revenue_summary].freeze
    WRITE_TOOLS = %w[add_order_comment change_order_status].freeze
    FIELDS = {
      'search_orders' => %w[number phone],
      'get_order' => %w[kind id], 'get_order_statuses' => %w[kind id],
      'add_order_comment' => %w[kind id content request_key],
      'change_order_status' => %w[kind id status expected_status request_key archive_reason archive_comment pause_reason_id displaced_by_id gluing_hours target_location_id what_to_test approval_question],
      'revenue_summary' => %w[from to]
    }.freeze

    def initialize(user, scopes)
      @user, @scopes = user, scopes
    end

    def call(tool, arguments)
      previous = User.current
      @tool = tool
      @args = arguments.stringify_keys
      invalid! unless FIELDS.key?(tool) && (@args.keys - FIELDS.fetch(tool)).empty?
      permitted = @scopes.include?('ais:read') &&
        (!WRITE_TOOLS.include?(tool) || @scopes.include?('ais:write')) &&
        (tool != 'revenue_summary' || @scopes.include?('ais:revenue'))
      forbidden! unless permitted && !@user.is_fired?
      User.current = @user
      Time.use_zone('Asia/Vladivostok') do
        Audited.audit_class.as_user(@user) do
          if WRITE_TOOLS.include?(tool)
            write
          else
            case tool
            when 'search_orders' then search
            when 'get_order' then details(record)
            when 'get_order_statuses' then statuses(record)
            when 'revenue_summary' then revenue
            end
          end
        end
      end
    ensure
      User.current = previous if defined?(previous)
    end

    private
    def invalid!(message = 'Некорректные параметры')
      raise Error.new('invalid_arguments', message)
    end
    def forbidden!
      raise Error.new('forbidden', 'Недостаточно прав АИС или разрешений OAuth')
    end
    def conflict!(message)
      raise Error.new('conflict', message)
    end
    def positive_integer!(value)
      invalid! unless value.is_a?(Integer) && value.positive?
      value
    end
    def text!(value, max)
      invalid! unless value.is_a?(String) && value.strip.present? && value.length <= max
      value.strip
    end
    def authorize!(object, query)
      forbidden! unless Pundit.policy!(@user, object).public_send(query)
    end
    def record
      klass = {'order' => Order, 'service_job' => ServiceJob}[@args['kind']]
      invalid! unless klass
      object = Pundit.policy_scope!(@user, klass).find(positive_integer!(@args['id']))
      authorize!(object, :read?)
      object
    end
    def kind(object)
      object.is_a?(Order) ? 'order' : 'service_job'
    end
    def current_status(object)
      object.is_a?(Order) ? object.status : object.repair_status&.code
    end
    def summary(object)
      {kind: kind(object), id: object.id,
       number: object.is_a?(Order) ? object.number : object.ticket_number,
       status: current_status(object), department_id: object.department_id}
    end
    def details(object)
      if object.is_a?(Order)
        summary(object).merge(object: object.object, quantity: object.quantity, archive_reason: object.archive_reason,
          updated_at: object.updated_at.iso8601, comments: object.notes.order(created_at: :desc).limit(20).map { |n| {id: n.id, content: n.content, author_id: n.author_id, created_at: n.created_at.iso8601} })
      else
        summary(object).merge(client_status: object.status, location_id: object.location_id,
          pause_reason_id: object.repair_pause_reason_id, updated_at: object.updated_at.iso8601,
          comments: object.device_notes.order(created_at: :desc).limit(20).map { |n| {id: n.id, content: n.content, author_id: n.user_id, created_at: n.created_at.iso8601} })
      end
    end
    def search
      invalid!('Укажите только номер или телефон') unless @args.keys.size == 1
      order_scope = Pundit.policy_scope!(@user, Order)
      jobs = Pundit.policy_scope!(@user, ServiceJob)
      if @args.key?('number')
        number = text!(@args['number'], 80)
        orders = order_scope.where(number: number)
        jobs = jobs.where(ticket_number: number)
      else
        raw = text!(@args['phone'], 40).gsub(/\D/, '')
        invalid!('Допустимы 6, 7, 10 или 11 цифр телефона') unless [6, 7, 10, 11].include?(raw.length)
        local, full = PhoneTools.convert_phone(raw)
        phones = [raw, local, full].reject(&:blank?).uniq
        clients = Client.where(full_phone_number: phones).or(Client.where(phone_number: phones)).select(:id)
        orders = order_scope.where(customer_type: 'Client', customer_id: clients)
        jobs = jobs.where(client_id: clients).or(jobs.where("regexp_replace(contact_phone, '[^0-9]', '', 'g') IN (?)", phones))
      end
      candidates = orders.order(id: :desc).limit(21).to_a + jobs.order(id: :desc).limit(21).to_a
      matches = candidates.select { |item| Pundit.policy!(@user, item).read? }
      {matches: matches.first(20).map { |item| summary(item) }, truncated: candidates.length > 20,
       instruction: 'Для изменения выберите точные kind и id; номер и телефон не являются ID.'}
    end
    def statuses(object)
      if object.is_a?(Order)
        authorize!(object, :change_status?)
        index = Order::NEW_STATUSES.index(object.status)
        next_status = index && Order::NEW_STATUSES[index + 1]
        {current: object.status, available: Order::STATUSES, transitions: next_status ? [{status: next_status, required: next_status == 'archive' ? ['archive_reason'] : []}] : [],
         archive_reasons: Order::ARCHIVE_REASONS, rule: 'Последовательность кнопки статуса АИС; архив требует причину.'}
      else
        authorize!(object, :update_repair_status?)
        owner = object.current_in_progress_user
        busy = ServiceJob.active_in_progress_for(@user).where.not(id: object.id).exists?
        transitions = RepairStatus.active.ordered.reject(&:completed?).map do |s|
          {status: s.code, allowed: !(s.in_progress? && (busy || (owner && owner.id != @user.id))),
           required: s.paused? ? ['pause_reason_id'] : []}
        end
        {current: current_status(object), available: RepairStatus.active.ordered.map { |s| {code: s.code, name: s.name} },
         transitions: transitions, pause_reasons: RepairPauseReason.active.ordered.map { |r| {id: r.id, code: r.code, name: r.name,
           required: {RepairPauseReason::URGENT_REPAIR => ['displaced_by_id'], RepairPauseReason::GLUING => ['gluing_hours'],
             RepairPauseReason::TESTING => ['target_location_id', 'what_to_test'], RepairPauseReason::WAITING_APPROVAL => ['approval_question']}[r.code] || []} },
         testing_targets: Location.testing_targets_for(object).map { |l| {id: l.id, name: l.name} },
         rule: 'Завершение через штатную выдачу АИС. Перехват и вытеснение другого ремонта выполняются в UI АИС.'}
      end
    end
    def write
      key = text!(@args['request_key'], 128)
      invalid!('request_key: 16–128 букв, цифр, дефисов или подчёркиваний') unless key.match?(/\A[A-Za-z0-9_-]{16,128}\z/)
      object = record
      # Recheck permissions even on replay; a revoked role never retrieves a cached result.
      authorize_write!(object)
      fingerprint = Digest::SHA256.hexdigest(JSON.generate([@tool, @args.sort.to_h]))
      @outbox = []
      result = @user.with_lock do
        existing = McpWrite.find_by(user_id: @user.id, request_key: key)
        if existing
          conflict!('request_key уже использован с другими параметрами') unless existing.fingerprint == fingerprint
          @entry = existing
          existing.result
        else
          entry = McpWrite.create!(user: @user, request_key: key, fingerprint: fingerprint,
            tool: @tool, record_type: object.class.name, record_id: object.id)
          payload = object.with_lock do
            authorize_write!(object)
            @tool == 'add_order_comment' ? comment(object) : change_status(object)
          end
          entry.update!(result: payload, outcome: 'succeeded', outbox: @outbox)
          @entry = entry
          payload
        end
      end
      @entry.dispatch_outbox
      result
    rescue StandardError => e
      Rails.logger.warn({event: 'mcp_write_failed', user_id: @user.id, tool: @tool,
        record_type: object&.class&.name, record_id: object&.id, outcome: e.class.name, at: Time.current.iso8601}.to_json)
      raise
    end
    def authorize_write!(object)
      forbidden! if @user.is_fired?
      if @tool == 'add_order_comment'
        authorize!(object.is_a?(Order) ? OrderNote : object, object.is_a?(Order) ? :create? : :read?)
      else
        authorize!(object, object.is_a?(Order) ? :change_status? : :update_repair_status?)
      end
    end
    def comment(object)
      content = text!(@args['content'], 4000)
      note = if object.is_a?(Order)
        object.notes.create!(content: content, author: @user)
      else
        object.device_notes.create!(content: content, user: @user)
      end
      {kind: kind(object), id: object.id, comment_id: note.id}
    end
    def change_status(object)
      target = text!(@args['status'], 40)
      expected = text!(@args['expected_status'], 40)
      conflict!('Статус изменился. Заново получите допустимые переходы.') unless current_status(object) == expected
      if object.is_a?(Order)
        invalid! unless (@args.keys & %w[pause_reason_id displaced_by_id gluing_hours target_location_id what_to_test approval_question]).empty?
        next_status = statuses(object)[:transitions].first&.fetch(:status)
        invalid!('Переход не разрешён кнопкой статуса АИС') unless next_status == target
        changes = {status: target}
        if target == 'archive'
          reason = @args['archive_reason']
          invalid!('Укажите допустимую причину архива') unless Order::ARCHIVE_REASONS.include?(reason)
          changes[:archive_reason] = reason
          changes[:archive_comment] = text!(@args['archive_comment'], 4000) if @args.key?('archive_comment')
        else
          invalid! unless (@args.keys & %w[archive_reason archive_comment]).empty?
        end
        object.update!(changes) # Same model callbacks (including 1C jobs) as OrdersController.
      else
        invalid! unless (@args.keys & %w[archive_reason archive_comment]).empty?
        repair_status(object, target)
      end
      {kind: kind(object), id: object.id, status: current_status(object)}
    end
    def repair_status(object, target)
      status = RepairStatus.active.find_by(code: target)
      invalid!('Завершение ремонта выполняется через выдачу АИС') unless status && !status.completed?
      if status.in_progress?
        conflict!('Другой ремонт в работе; используйте UI АИС для вытеснения') if ServiceJob.active_in_progress_for(@user).where.not(id: object.id).exists?
        owner = object.current_in_progress_user
        conflict!('Перехват другого техника выполняется в UI АИС') if owner && owner.id != @user.id
      end
      reason = status.paused? ? RepairPauseReason.active.find(positive_integer!(@args['pause_reason_id'])) : nil
      allowed = %w[kind id status expected_status request_key]
      allowed += ['pause_reason_id'] if status.paused?
      allowed += ['displaced_by_id'] if reason&.urgent_repair?
      allowed += ['gluing_hours'] if reason&.gluing?
      allowed += %w[target_location_id what_to_test] if reason&.testing?
      allowed += ['approval_question'] if reason&.waiting_approval?
      invalid! unless (@args.keys - allowed).empty?
      displaced = nil
      if reason&.urgent_repair?
        displaced = ServiceJob.find(positive_integer!(@args['displaced_by_id']))
        authorize!(displaced, :read?)
        invalid! if displaced.id == object.id
      end
      hours = reason&.gluing? ? positive_integer!(@args['gluing_hours']) : nil
      invalid! if hours && hours > 8760
      location = reason&.testing? ? Location.testing_targets_for(object).find(positive_integer!(@args['target_location_id'])) : nil
      test_text = reason&.testing? ? text!(@args['what_to_test'], 4000) : nil
      question = reason&.waiting_approval? ? text!(@args['approval_question'], 4000) : nil
      result = ServiceJobs::RepairStatusTransition.call(service_job: object, status: status, user: @user,
        pause_reason: reason, displaced_by: displaced, gluing_hours: hours, testing_target: location,
        what_to_test: test_text, approval_question: question)
      change = result[:change]
      # These are the same business entities/jobs created by update_repair_status in the UI.
      @outbox << {kind: 'gluing', id: change.id, run_at: hours.hours.from_now.iso8601} if change && hours
      if location
        session = result[:testing]
        @outbox << {kind: 'testing_telegram', id: session.id}
        @outbox << {kind: 'testing_in_app', id: session.id}
      end
      if question
        approval = result[:approval]
        @outbox << {kind: 'approval_telegram', id: approval.id}
        @outbox << {kind: 'approval_in_app', id: approval.id}
      end
    end
    def revenue
      authorize!(:weekly_markup_dashboard, :details?)
      invalid! unless %w[from to].all? { |key| @args[key].is_a?(String) && @args[key].match?(/\A\d{4}-\d{2}-\d{2}\z/) }
      from, to = Date.iso8601(@args['from']), Date.iso8601(@args['to'])
      invalid!('Период не более 367 дней, обе даты включены') if to < from || (to - from).to_i > 366
      data = WeeklyMarkup::DashboardData.new(from: from, to: to).call
      stringify_money({period: {from: from.iso8601, to: to.iso8601, time_zone: 'Asia/Vladivostok', inclusive: true},
        source: 'WeeklyMarkup::DashboardData / импорт регистра 1С', methodology_version: data[:methodology_version],
        definition: 'Выручка импортированного регистра за вычетом исключённых операций по методологии dashboard. Не эквивалентна денежным поступлениям.',
        missing_dates: data[:missing_dates], incomplete_dates: data[:incomplete_dates],
        as_of_local: data[:as_of_local], versions: data[:versions],
        complete: data[:missing_dates].empty? && data[:incomplete_dates].empty?,
        branches: data[:branches].map { |b| {warehouse_id: b[:warehouse_id], name: b[:name], totals: b[:total],
          loaded_dates: b[:days].map { |day| day[:date] },
          absent_dates: (from..to).to_a - b[:days].map { |day| day[:date] }} }, totals: data[:totals]})
    rescue ArgumentError
      invalid!('Ожидаются даты YYYY-MM-DD и допустимый период')
    end
    def stringify_money(value)
      case value
      when Hash then value.transform_values { |item| stringify_money(item) }
      when Array then value.map { |item| stringify_money(item) }
      when BigDecimal then value.to_s('F')
      when Date then value.iso8601
      else value
      end
    end
  end
end
