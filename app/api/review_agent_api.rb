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

  rescue_from Grape::Exceptions::ValidationErrors do |e|
    error!({ status: 400, detail: e.message }, 400)
  end

  resource :review_agent do
    desc 'Сотрудники локации «Бар» по всем филиалам города'
    params do
      requires :city, type: String
    end
    get 'employees' do
      authorize :list_employees, GisReview

      # Сотрудники отдаются по ГОРОДУ, а не по филиалу: человек сегодня работает
      # на Океанском, завтра на Русской, и агент не должен об этом знать.
      city = City.find_by(name: params[:city])
      error!({ status: 404, detail: "Город не найден: #{params[:city]}" }, 404) if city.nil?

      employees = User.active.located_at(Location.bar.in_city(city)).order(:surname, :name)

      { city: city.name, employees: employees.map { |u| { id: u.id, name: u.short_name } } }
    end

    desc 'Создать (или обновить) отзыв 2ГИС'
    params do
      requires :external_review_id, type: String
      requires :city,               type: String
      requires :rating,             type: Integer, values: 1..5
      requires :date,               type: DateTime
      requires :status,             type: String, values: GisReview::AGENT_STATUSES.keys
      optional :branch_code,        type: String
      optional :branch_name,        type: String
      optional :branch_2gis_id,     type: String
      optional :author,             type: String
      optional :text,               type: String
      optional :employee_id,        type: Integer
    end
    post 'reviews' do
      authorize :create, GisReview

      review = GisReview.find_or_initialize_by(external_review_id: params[:external_review_id])
      new_record = review.new_record?

      employee = nil
      if params[:employee_id].present?
        employee = User.find_by(id: params[:employee_id])
        if employee.nil?
          error!({ status: 422, detail: "Сотрудник не найден: #{params[:employee_id]}" }, 422)
        end
      end

      # Отзыв с незнакомым городом всё равно сохраняем: у агента нет очереди
      # повторов, и потерять отзыв из-за расхождения в написании нельзя.
      # Связь остаётся пустой, расхождение видно в логе.
      city = City.find_by(name: params[:city])
      if city.nil?
        logger.warn("[ReviewAgentApi] Город не найден: #{params[:city]} (отзыв #{params[:external_review_id]})")
      end

      review.assign_attributes(
        city_name:      params[:city],
        city:           city,
        branch_code:    params[:branch_code],
        branch_name:    params[:branch_name],
        branch_2gis_id: params[:branch_2gis_id],
        rating:         params[:rating],
        author:         params[:author],
        reviewed_at:    params[:date],
        text:           params[:text]
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

        status(new_record ? 201 : 200)
        present review, with: Entities::GisReviewEntity
      else
        error!({ status: 422, detail: review.errors.full_messages.to_sentence }, 422)
      end
    rescue ActiveRecord::RecordNotUnique
      # Два одновременных прогона агента с одним и тем же отзывом.
      error!({ status: 409, detail: 'Отзыв с таким external_review_id уже существует' }, 409)
    end

    desc 'Проставить сотрудника отзыву, который агент определил позже'
    params do
      requires :external_review_id, type: String
      # nil — снять привязку и вернуть отзыв в очередь ручного разбора.
      optional :employee_id, type: Integer
    end
    # Адресуемся по external_review_id, а не по нашему id: внутренний
    # идентификатор агент может не хранить, внешний у него есть всегда.
    # requirements — иначе точка в идентификаторе была бы съедена как формат.
    patch 'reviews/:external_review_id/employee',
          requirements: { external_review_id: %r{[^/]+} } do
      authorize :update_employee, GisReview

      review = GisReview.find_by(external_review_id: params[:external_review_id])
      if review.nil?
        error!({ status: 404, detail: "Отзыв не найден: #{params[:external_review_id]}" }, 404)
      end

      # Негатив живёт своей веткой — сотрудник там не проставляется.
      if review.negative?
        error!({ status: 422, detail: 'Негативный отзыв нельзя привязать к сотруднику' }, 422)
      end

      # Главный гейт: assigned_by заполняется ТОЛЬКО при привязке через
      # интерфейс, из API остаётся пустым. Значит непустое значение = отзыва
      # уже касался человек, и прогон агента не должен отменять его решение.
      if review.assigned_by.present?
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
          error!({ status: 422, detail: "Сотрудник не найден среди кандидатов отзыва: #{params[:employee_id]}" }, 422)
        end

        review.update!(user: employee, status: :assigned)
      else
        review.update!(user: nil, status: :need_assignment)
      end

      present review, with: Entities::GisReviewEntity
    end
  end
end
