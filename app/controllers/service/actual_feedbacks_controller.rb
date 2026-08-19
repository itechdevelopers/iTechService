module Service
  class ActualFeedbacksController < ApplicationController
    skip_after_action :verify_authorized, only: :index
    respond_to :js

    # Один ответ обслуживает два места: popover иконки-«трубки» в topbar и
    # блоки «Заказы»/«Сервис» на дашборде сотрудника. Коллекции материализуются
    # (to_a), потому что вьюха рендерит каждую из них дважды — с разными
    # префиксами DOM-id.
    def index
      @feedbacks = FeedbacksQuery.new(policy_scope(Feedback)).actual.to_a
      @order_feedbacks = policy_scope(OrderFeedback).actual.new_first.to_a
    end
  end
end
