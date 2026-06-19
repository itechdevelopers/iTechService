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
    @rows = QuackControlQuery.new(@month).rows
  end

  private

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
