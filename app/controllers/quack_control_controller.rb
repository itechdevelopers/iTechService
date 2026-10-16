# frozen_string_literal: true

# Страница «Кря-контроль» — лёгкий анти-рейтинг «кто забывает брать устройство
# в работу». Read-only агрегация поверх RepairAttentionMarker («айс»).
class QuackControlController < ApplicationController
  def show
    authorize :quack_control, :show?

    @month = parse_month
    @prev_month = @month.prev_month
    # «вперёд за текущий месяц нельзя»: стрелка вперёд только когда мы в прошлом
    @next_month = @month < current_month ? @month.next_month : nil

    query = QuackControlQuery.new(@month)
    @primary_rows = query.primary_rows
    @extended_rows = query.extended_rows
    @total = query.total
    @decades = query.decade_counts
    # Сравнение с прошлым месяцем показываем только для ЗАВЕРШЁННЫХ месяцев.
    # Флаг отделяет «текущий месяц → бейдж скрыт» от «завершён, но прошлый пуст → прочерк».
    @month_completed = @month < current_month
    @delta_percent = month_over_month_delta(query)
    # Строка, которую раскрыть сразу — после #exclude, чтобы убирать работы подряд.
    @open_user_id = params[:open].to_i
  end

  # Убирает строку расшифровки из счёта: все засчитанные за месяц маркеры пары
  # «сотрудник × работа». Маркеры не удаляем — кнопка «Взять в работу» из Telegram
  # ищет маркер по start_token, и после destroy она отдавала бы 404.
  def exclude
    authorize :quack_control, :exclude?

    month = parse_month
    now = Time.current
    excluded = QuackControlQuery.new(month)
                                .counted_markers(user_id: params[:user_id], service_job_id: params[:service_job_id])
                                .update_all(quack_excluded_at: now, quack_excluded_by_id: current_user.id, updated_at: now)

    if excluded.positive?
      flash[:notice] = t('.done', ticket: ServiceJob.find_by(id: params[:service_job_id])&.ticket_number)
    else
      flash[:alert] = t('.nothing')
    end
    redirect_to quack_control_path(month: month.strftime('%Y-%m'), open: params[:user_id])
  end

  private

  # ±% изменения тотала относительно прошлого месяца.
  # Только для ЗАВЕРШЁННЫХ месяцев (текущий идущий месяц сравнивать рано → nil).
  # При нулевом прошлом месяце процент не определён → nil (во вью покажем прочерк).
  def month_over_month_delta(query)
    return nil unless @month < current_month

    prev_total = QuackControlQuery.new(@prev_month).total
    return nil if prev_total.zero?

    ((query.total - prev_total).to_f / prev_total * 100).round
  end

  def current_month
    Date.current.beginning_of_month
  end

  # Парсит ?month=YYYY-MM, клампит к текущему месяцу (в будущее не пускаем)
  def parse_month
    requested =
      begin
        Date.strptime(params[:month], '%Y-%m').beginning_of_month if params[:month].present?
      rescue ArgumentError
        nil
      end

    [requested || current_month, current_month].min
  end
end
