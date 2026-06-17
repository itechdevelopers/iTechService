# frozen_string_literal: true

class ClientRequestsController < ApplicationController
  # Цикл 1: только пустой index, чтобы пункт меню открывался.
  # Цикл 2 добавит new/create (модалка) и наполнит таблицу.
  def index
    authorize ClientRequest
    @client_requests = ClientRequest.recent
  end
end
