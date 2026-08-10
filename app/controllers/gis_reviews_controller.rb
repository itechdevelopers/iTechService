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

  private

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
