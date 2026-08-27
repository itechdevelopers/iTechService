# Приём отзывов 2ГИС от внешнего парсер-агента.
#
#   GET  /api/v1/review_agent/employees?city=Владивосток
#   POST /api/v1/review_agent/reviews
#
# Аутентификация — общий токен-механизм API (Authorization: Token token="..."),
# доступ — только сервисному юзеру с role: 'api' (GisReviewPolicy).
class ReviewAgentApi < Grape::API
  version 'v1', using: :path
  before { authenticate! }

  helpers do
    # ВАЖНО: именно Rails.logger, а не хелпер `logger` из app/api/api.rb — тот
    # отдаёт Grape::API.logger, отдельный Logger в stdout процесса, и его записи
    # в production.log не попадают. Тот же приём, что в TranscriptionApi.
    def log_agent(message)
      Rails.logger.info("[ReviewAgentApi] #{message}")
    end

    def warn_agent(message)
      Rails.logger.warn("[ReviewAgentApi] #{message}")
    end

    # Всё, что реально прислал агент, включая поля, которых нет в нашем
    # контракте. route_info — служебный ключ Grape, в логе он бесполезен.
    def loggable_params
      params.to_hash.except('route_info')
    end

    # Отказ агенту — всегда с записью в лог: без неё «агент прислал, но у вас
    # ничего не появилось» невозможно разобрать постфактум.
    def agent_error!(detail, code)
      warn_agent("#{code} #{detail}")
      error!({ status: code, detail: detail }, code)
    end
  end

  rescue_from Grape::Exceptions::ValidationErrors do |e|
    Rails.logger.warn("[ReviewAgentApi] 400 #{e.message}")
    error!({ status: 400, detail: e.message }, 400)
  end

  resource :review_agent do
    desc 'Сотрудники локации «Бар» по всем филиалам города'
    params do
      requires :city, type: String
    end
    get 'employees' do
      authorize :list_employees, GisReview
      log_agent("GET employees city=#{params[:city].inspect}")

      # Сотрудники отдаются по ГОРОДУ, а не по филиалу: человек сегодня работает
      # на Океанском, завтра на Русской, и агент не должен об этом знать.
      city = City.find_by(name: params[:city])
      agent_error!("Город не найден: #{params[:city]}", 404) if city.nil?

      employees = User.active.located_at(Location.bar.in_city(city)).order(:surname, :name)
      log_agent("GET employees city=#{city.name.inspect} → отдано #{employees.size}")

      { city: city.name, employees: employees.map { |u| { id: u.id, name: u.short_name } } }
    end

    desc 'Создать (или обновить) отзыв 2ГИС'
    params do
      requires :external_review_id, type: String
      requires :city,               type: String
      # VL.ru разрешает отзыв без оценки, и агент не додумывает звёзды по тексту.
      optional :rating,             type: Integer, values: 1..5
      requires :date,               type: DateTime
      requires :status,             type: String, values: GisReview::AGENT_STATUSES.keys
      # Площадка — источник истины по контракту. Поле опциональное для запросов,
      # отправленных до перехода на новый контракт: тогда выводим из префикса.
      optional :source,             type: String, values: GisReview::SOURCES
      optional :branch_code,        type: String
      optional :branch_name,        type: String
      # Идентификатор филиала на площадке: id фирмы 2ГИС, businessId Яндекса,
      # id филиала VL.ru. Старые имена принимаем тоже — у агента переход
      # постепенный, а ломать приём из-за переименования поля незачем.
      optional :platform_branch_id, type: String
      optional :branch_external_id, type: String
      optional :branch_2gis_id,     type: String
      optional :author,             type: String
      optional :text,               type: String
      optional :employee_id,        type: Integer
    end
    post 'reviews' do
      authorize :create, GisReview
      # Пишем СЫРЫЕ params, а не declared: declared оставляет только объявленные
      # поля, и если агент начнёт слать что-то новое (например, площадку отзыва),
      # мы этого в логе не увидим — а именно по логу и придётся выяснять, что
      # он уже умеет присылать.
      log_agent("POST reviews #{loggable_params.to_json}")

      # Ищем по ПАРЕ (площадка, идентификатор): у разных площадок нумерация
      # независимая, и один и тот же id — это разные отзывы.
      # Префикс площадки из идентификатора срезаем: он транспортная деталь, а
      # площадка живёт в source. Иначе отзыв 2ГИС, приехавший до смены контракта
      # как «265062064» и после как «2gis:265062064», задвоился бы.
      source = params[:source].presence ||
               GisReview.source_from_external_id(params[:external_review_id])
      external_id = GisReview.strip_source_prefix(params[:external_review_id])
      review = GisReview.find_or_initialize_by(source: source, external_review_id: external_id)
      new_record = review.new_record?

      employee = nil
      if params[:employee_id].present?
        employee = User.find_by(id: params[:employee_id])
        agent_error!("Сотрудник не найден: #{params[:employee_id]}", 422) if employee.nil?
      end

      # Отзыв с незнакомым городом всё равно сохраняем: у агента нет очереди
      # повторов, и потерять отзыв из-за расхождения в написании нельзя.
      # Связь остаётся пустой, расхождение видно в логе.
      city = City.find_by(name: params[:city])
      if city.nil?
        warn_agent("Город не найден: #{params[:city]} (отзыв #{params[:external_review_id]}) — сохраняем без привязки к городу")
      end

      department = GisReview.department_for(params[:branch_code])
      if department.nil? && params[:branch_code].present?
        warn_agent("Подразделение не найдено по коду филиала #{params[:branch_code].inspect} (отзыв #{params[:external_review_id]})")
      end

      review.assign_attributes(
        city_name:          params[:city],
        city:               city,
        department:         department,
        branch_code:        params[:branch_code],
        branch_name:        params[:branch_name],
        platform_branch_id: params[:platform_branch_id].presence ||
                            params[:branch_external_id].presence ||
                            params[:branch_2gis_id],
        rating:             params[:rating],
        author:             params[:author],
        reviewed_at:        params[:date],
        text:               params[:text]
      )

      # Статус и сотрудника выставляем ТОЛЬКО при создании: агент пере-присылает
      # отзывы текущего месяца на каждом прогоне, а руководитель мог за это время
      # привязать сотрудника или продвинуть негатив по статусам. Повторная
      # отправка не должна откатывать эту работу.
      if new_record
        review.status = GisReview::AGENT_STATUSES.fetch(params[:status])
        review.user = employee
      end

      if review.save
        # Уведомляем только о ПЕРВОМ появлении негатива: агент шлёт отзывы
        # текущего месяца на каждом прогоне, а колокольчик и Телеграм не должны
        # звенеть по одному отзыву снова и снова.
        review.notify_about_creation if new_record && review.negative?

        log_agent(
          "POST reviews → #{new_record ? 'создан' : 'обновлён'} ##{review.id} " \
          "(#{review.source}:#{review.external_review_id}), статус #{review.status}, " \
          "сотрудник #{review.user_id.inspect}, подразделение #{review.department_id.inspect}"
        )
        status(new_record ? 201 : 200)
        present review, with: Entities::GisReviewEntity
      else
        agent_error!(review.errors.full_messages.to_sentence, 422)
      end
    rescue ActiveRecord::RecordNotUnique
      # Два одновременных прогона агента с одним и тем же отзывом.
      agent_error!('Отзыв с таким external_review_id уже существует', 409)
    end

    desc 'Проставить сотрудника отзыву, который агент определил позже'
    params do
      requires :external_review_id, type: String
      # Как и в POST: не прислали — выводим площадку из префикса идентификатора.
      optional :source, type: String, values: GisReview::SOURCES
      # nil — снять привязку и вернуть отзыв в очередь ручного разбора.
      optional :employee_id, type: Integer
    end
    # Адресуемся по external_review_id, а не по нашему id: внутренний
    # идентификатор агент может не хранить, внешний у него есть всегда.
    # requirements — иначе точка в идентификаторе была бы съедена как формат.
    patch 'reviews/:external_review_id/employee',
          requirements: { external_review_id: %r{[^/]+} } do
      authorize :update_employee, GisReview
      log_agent("PATCH employee review=#{params[:external_review_id]} employee_id=#{params[:employee_id].inspect}")

      source = params[:source].presence ||
               GisReview.source_from_external_id(params[:external_review_id])
      external_id = GisReview.strip_source_prefix(params[:external_review_id])
      review = GisReview.find_by(source: source, external_review_id: external_id)
      agent_error!("Отзыв не найден: #{source}:#{external_id}", 404) if review.nil?

      # Негатив живёт своей веткой — сотрудник там не проставляется.
      agent_error!('Негативный отзыв нельзя привязать к сотруднику', 422) if review.negative?

      # Главный гейт: assigned_by заполняется ТОЛЬКО при привязке через
      # интерфейс, из API остаётся пустым. Значит непустое значение = отзыва
      # уже касался человек, и прогон агента не должен отменять его решение.
      if review.assigned_by.present?
        warn_agent(
          "409 отзыв #{review.external_review_id} уже привязан вручную " \
          "(#{review.assigned_by.short_name}) — заявку агента игнорируем"
        )
        error!({
          status: 409,
          detail: 'Отзыв уже привязан вручную',
          assigned_by: review.assigned_by.short_name,
          assigned_at: review.updated_at
        }, 409)
      end

      if params[:employee_id].present?
        # Кандидаты те же, что в интерфейсе и в методе employees — сотрудники
        # бара города отзыва. Чужой город отклоняем.
        employee = review.employee_candidates.find_by(id: params[:employee_id])
        if employee.nil?
          agent_error!("Сотрудник не найден среди кандидатов отзыва: #{params[:employee_id]}", 422)
        end

        review.update!(user: employee, status: :assigned)
        log_agent("PATCH employee → отзыв ##{review.id} привязан к #{employee.short_name} (##{employee.id})")
      else
        review.update!(user: nil, status: :need_assignment)
        log_agent("PATCH employee → с отзыва ##{review.id} снята привязка")
      end

      present review, with: Entities::GisReviewEntity
    end

    desc 'Авария сбора отзывов или её восстановление'
    params do
      requires :source,     type: String, values: ReviewSourceAlert::SOURCES
      # Решение принимаем по alert_type; status агент шлёт как справочный —
      # поля дублируют друг друга, и без явного приоритета пара
      # source_recovered + error была бы неразрешимой.
      requires :alert_type, type: String, values: ReviewSourceAlert::ALERT_TYPES
      optional :status,     type: String
      # Пусто (null или отсутствует) — авария площадки целиком.
      optional :branch_code, type: String
      # Идентификатор аварии у агента: храним для сверки с его логами,
      # уникальность строим не на нём (см. ReviewSourceAlert).
      optional :external_alert_id,    type: String
      optional :branch_name,          type: String
      optional :city,                 type: String
      optional :first_failed_at,      type: DateTime
      optional :last_failed_at,       type: DateTime
      optional :consecutive_failures, type: Integer
      optional :hours_failed,         type: Float
      optional :message,              type: String
      optional :error,                type: String
    end
    post 'alerts' do
      authorize :create, ReviewSourceAlert
      log_agent("POST alerts #{loggable_params.to_json}")

      branch_code = ReviewSourceAlert.normalize_branch_code(params[:branch_code])

      if params[:alert_type] == 'source_recovered'
        resolved = ReviewSourceAlert.resolve(
          source: params[:source], branch_code: branch_code, message: params[:message]
        )
        # Grape по умолчанию отвечает на POST 201 Created, а восстановление
        # ничего не создаёт — без явного статуса агент увидит «создано».
        status 200

        if resolved.empty?
          # Не ошибка: Айс могли поднять уже после начала аварии, или её
          # закрыли руками. Ронять агенту задачу из-за нашего рассинхрона незачем.
          log_agent("POST alerts → восстановление #{params[:source]}/#{branch_code.presence || 'вся площадка'} без открытой аварии")
          { status: 'no_open_alert' }
        else
          log_agent("POST alerts → закрыто аварий: #{resolved.size} (#{resolved.map(&:full_label).join('; ')})")
          { status: 'resolved', alert_ids: resolved.map(&:id) }
        end
      else
        department = ReviewSourceAlert.department_for(branch_code)
        if department.nil? && branch_code.present?
          warn_agent("Подразделение не найдено по коду филиала #{branch_code.inspect} (авария #{params[:source]})")
        end

        alert, first_appearance = ReviewSourceAlert.open_or_update(
          source:               params[:source],
          branch_code:          branch_code,
          alert_type:           params[:alert_type],
          external_alert_id:    params[:external_alert_id],
          branch_name:          params[:branch_name],
          city_name:            params[:city],
          department:           department,
          first_failed_at:      params[:first_failed_at],
          last_failed_at:       params[:last_failed_at],
          consecutive_failures: params[:consecutive_failures],
          hours_failed:         params[:hours_failed],
          message:              params[:message],
          last_error:           params[:error]
        )

        # Звоним только на первое появление: агент шлёт аварию на каждом
        # прогоне, пока она держится. Рецидив после восстановления — это уже
        # новая запись, и уведомление по нему придёт снова.
        alert.notify_about_opening if first_appearance

        log_agent(
          "POST alerts → #{first_appearance ? 'открыта' : 'обновлена'} авария ##{alert.id} " \
          "(#{alert.full_label}), сбоев подряд #{alert.consecutive_failures.inspect}"
        )
        status(first_appearance ? 201 : 200)
        { status: first_appearance ? 'created' : 'already_exists', alert_id: alert.id }
      end
    rescue ActiveRecord::RecordNotUnique
      # Два прогона агента столкнулись на одной и той же аварии.
      agent_error!('Авария по этой площадке и филиалу уже открыта', 409)
    end
  end
end
