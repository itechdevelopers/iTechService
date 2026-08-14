# frozen_string_literal: true

class GisReviewsController < ApplicationController
  # Страница «Негативные отзывы» — только негативная ветка (1–3★). Позитивные
  # отзывы сотрудник видит у себя в профиле (цикл 4), отдельной страницы у них нет.
  #
  # Чипы здесь — ФИЛЬТР-отсев, а не приоритет-сортировка как в device_unlock_requests:
  # негативных отзывов мало и работа с ними идёт очередями («покажи только новые»),
  # поэтому прятать обработанные полезнее, чем опускать их вниз.
  def index
    authorize GisReview

    @statuses = GisReview::NEGATIVE_STATUSES
    # Ключи валидируем по белому списку: в where уходят только известные статусы.
    @selected_statuses = Array(params[:status]).select { |s| @statuses.include?(s) }
    @status_counts = status_counts

    scope = GisReview.negative.recent.includes(:user, :comments)
    scope = scope.where(status: @selected_statuses) if @selected_statuses.any?
    @gis_reviews = scope
  end

  # Смена статуса обработки негатива кнопкой-ссылкой remote: true.
  def update_status
    @gis_review = find_record GisReview

    if @gis_review.update(status_params)
      respond_to do |format|
        format.js   # update_status.js.erb — перерисовка одной строки
        format.html { redirect_to gis_reviews_path, notice: t('.updated') }
      end
    else
      head :unprocessable_entity
    end
  end

  # Инлайн-комментарий прямо из строки таблицы (паттерн device_unlock_requests):
  # создаём Comment сами и перерисовываем строку, чтобы «последний комментарий»
  # обновился без перезагрузки.
  def add_comment
    @gis_review = find_record GisReview
    comment = @gis_review.comments.build(content: params[:content], user: current_user)

    if comment.save
      respond_to do |format|
        format.js   # add_comment.js.erb
        format.html { redirect_to gis_reviews_path }
      end
    else
      head :unprocessable_entity # пустой комментарий — молча, без перерисовки
    end
  end

  # Часики в колонке комментариев — модалка со всеми комментариями отзыва
  # (в таблице виден только последний).
  def comments
    @gis_review = find_record GisReview
    render 'shared/show_modal_form'
  end

  # Страница привязки сотрудников: неопределённые отзывы (агент не нашёл имени)
  # и уже привязанные — на одном экране, чтобы суперадмин мог перекинуть отзыв
  # на другого сотрудника, не разыскивая его по профилям.
  def assignment
    authorize GisReview

    @statuses = %w[need_assignment assigned]
    @selected_statuses = Array(params[:status]).select { |s| @statuses.include?(s) }
    @status_counts = assignment_status_counts

    scope = GisReview.where(status: @statuses).recent.includes(:user, :city)
    scope = scope.where(status: @selected_statuses) if @selected_statuses.any?
    @gis_reviews = scope
    @candidates_by_city_id = candidates_by_city_id(@gis_reviews)

    # Сводка за текущий месяц над таблицей — заказчик прислал скриншот этой
    # страницы с просьбой показывать «количество отзывов по филиалам и за месяц».
    @month = Date.current
    @stats = GisReviewStatsQuery.new(month: @month).call
  end

  # Полная статистика: всего → города → подразделения, отдельно разбивка по
  # площадкам. Месяц и площадка задаются параметрами.
  def statistics
    authorize GisReview

    @month = parse_month(params[:month])
    @source = params[:source].presence_in(GisReview::SOURCES)
    @stats = GisReviewStatsQuery.new(month: @month, source: @source).call
  end

  # Привязка сотрудника к отзыву и переброс на другого — один экшен: разница
  # только в правах (переброс уже привязанного — привилегия суперадмина).
  # Пустое значение снимает привязку и возвращает отзыв в очередь: «привязали
  # не тому, а кому надо — пока не знаем».
  def assign
    @gis_review = find_record GisReview
    # Гейт заказчика: перекинуть УЖЕ привязанный отзыв может только суперадмин.
    authorize @gis_review, :reassign? if @gis_review.user_id.present?

    if params[:user_id].blank?
      @gis_review.assign_attributes(user: nil, assigned_by: current_user, status: :need_assignment)
    else
      # Ищем строго среди кандидатов отзыва — защита от подмены id сотрудником
      # чужого города (тот же приём, что в device_unlock_requests#notify_approval).
      employee = @gis_review.employee_candidates.find_by(id: params[:user_id])
      return head :unprocessable_entity if employee.nil?

      @gis_review.assign_attributes(user: employee, assigned_by: current_user, status: :assigned)
    end

    if @gis_review.save
      respond_to do |format|
        format.js   # assign.js.erb — перерисовка строки
        format.html { redirect_to assignment_gis_reviews_path, notice: t('.updated') }
      end
    else
      head :unprocessable_entity
    end
  end

  # Вкладка «Отзывы 2ГИС» в профиле сотрудника: его отзывы помесячно.
  # Авторизуем по ЮЗЕРУ, а не по GisReview: свои отзывы сотрудник видит всегда,
  # чужие — только суперадмин или обладатель права (UserPolicy#gis_reviews?).
  def employee
    @user = User.find(filter_params[:user_id])
    authorize @user, :gis_reviews?

    # Всего у сотрудника — для подписи над таблицей; выборка ниже уже с фильтром.
    @total_count = GisReview.where(user_id: @user.id).count

    scope = GisReviewFilter.call(collection: GisReview.all, filter: filter_params).collection
    @gis_reviews = paginate(scope.recent)
    @table_name = 'user_table'

    respond_to do |format|
      format.js { render 'shared/index', locals: { resource_table_id: 'gis_reviews_user_table' } }
    end
  end

  private

  def filter_params
    params.require(:filter).permit(:user_id, :month, :year)
  end

  # Месяц из строки «2026-08»; мусор и отсутствие параметра → текущий месяц.
  def parse_month(value)
    Date.parse("#{value}-01")
  rescue ArgumentError, TypeError
    Date.current
  end

  # Кандидаты считаются ОДИН раз на город, а не на строку: иначе страница на
  # полсотни отзывов выдаёт полсотни одинаковых селектов сотрудников.
  def candidates_by_city_id(reviews)
    reviews.map(&:city_id).uniq.each_with_object({}) do |city_id, acc|
      locations = city_id.present? ? Location.bar.in_city(city_id) : Location.bar
      acc[city_id] = User.active.located_at(locations).order(:surname, :name)
    end
  end

  def assignment_status_counts
    GisReview.where(status: %w[need_assignment assigned])
             .group(:status).count
             .each_with_object(Hash.new(0)) do |(key, count), acc|
      name = key.is_a?(Integer) ? GisReview.statuses.key(key) : key.to_s
      acc[name] = count
    end
  end

  # Счётчики для чипов. group(:status).count отдаёт то integer-коды, то строки
  # (зависит от версии AR), поэтому ключи нормализуем к именам статусов.
  def status_counts
    GisReview.negative.group(:status).count.each_with_object(Hash.new(0)) do |(key, count), acc|
      name = key.is_a?(Integer) ? GisReview.statuses.key(key) : key.to_s
      acc[name] = count
    end
  end

  def status_params
    params.require(:gis_review).permit(:status)
  end
end
