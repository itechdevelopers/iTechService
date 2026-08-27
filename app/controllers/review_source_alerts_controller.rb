# frozen_string_literal: true

# Состояние источников отзывов. Страница читающая: аварии заводит и закрывает
# только парсер-агент через ReviewAgentApi, руками тут ничего не меняется.
class ReviewSourceAlertsController < ApplicationController
  def index
    authorize ReviewSourceAlert

    @health = ReviewSourceHealth.new
  end
end
