# frozen_string_literal: true

class OneCFunctionsController < ApplicationController
  def index
    authorize :one_c_function, :index?
    @article = params[:article].to_s.strip
    return unless params.key?(:article)

    @result = OneCArticleSearch.call(@article)
  rescue OneCArticleSearch::InvalidArguments => exception
    @error = exception.message
    render :index, status: :unprocessable_entity
  rescue OneCArticleSearch::Unavailable
    @error = '1С временно недоступна или ответ неполный. Данные не получены; повторите поиск позже.'
    render :index, status: :bad_gateway
  end
end
