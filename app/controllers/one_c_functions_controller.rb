# frozen_string_literal: true

class OneCFunctionsController < ApplicationController
  def index
    authorize :one_c_function, :index?
    @article = params[:article].to_s.strip
    return unless params.key?(:article)

    authorize :one_c_function, :article?
    @result = OneCArticleSearch.call(@article)
  rescue OneCArticleSearch::InvalidArguments => exception
    @error = exception.message
    render :index, status: :unprocessable_entity
  rescue OneCArticleSearch::Unavailable
    @error = '1С временно недоступна или ответ неполный. Данные не получены; повторите поиск позже.'
    render :index, status: :bad_gateway
  end

  def glass
    authorize :one_c_function, :glass?
    response.headers['Cache-Control'] = 'no-store'
    @lookup = OneCGlassLoyalty.read(session[:glass_loyalty_key])
  rescue Redis::BaseError
    @lookup = { error: 'Сервис временно недоступен. Повторите позже.' }
  end

  def glass_search
    authorize :one_c_function, :glass_search?
    session[:glass_loyalty_key] = OneCGlassLoyalty.start(params[:phone], current_user.id)
    redirect_to glass_one_c_functions_path
  rescue OneCGlassLoyalty::InvalidPhone => error
    @lookup = { error: error.message }
    render :glass, status: :unprocessable_entity
  rescue Redis::BaseError
    @lookup = { error: 'Сервис временно недоступен. Повторите позже.' }
    render :glass, status: :service_unavailable
  end

end
