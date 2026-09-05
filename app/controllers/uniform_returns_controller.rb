# frozen_string_literal: true

# Возврат формы при увольнении. Открыт тому, кто вправе редактировать сотрудника:
# вопрос задаётся в момент увольнения, и увольняющий должен уметь на него ответить,
# иначе увольнение упирается в отказ доступа.
class UniformReturnsController < ApplicationController
  before_action :set_employee

  def new
    @uniform_return = UniformReturn.new(employee: @employee, author: current_user,
                                        performed_on: Date.current)
    load_balance
  end

  def create
    # to_h обязателен: ActiveModel не принимает ActionController::Parameters.
    @uniform_return = UniformReturn.new(
      uniform_return_params.to_h.merge(employee: @employee, author: current_user)
    )

    if @uniform_return.save
      redirect_to user_path(@employee), notice: success_message
    else
      load_balance
      render :new
    end
  end

  private

  def set_employee
    @employee = User.find(params[:user_id])
    authorize @employee, :uniform_return?
  end

  # Что числится за сотрудником на момент открытия формы: пары «позиция → сколько».
  def load_balance
    balance = UniformOperationLine.holder_balance(@employee).reject { |_id, quantity| quantity.to_i.zero? }
    @on_hands = UniformStock.joins(:uniform_kind).includes(:uniform_kind)
                            .where(id: balance.keys).order('uniform_kinds.name').ordered
                            .map { |stock| [stock, balance[stock.id]] }
  end

  def success_message
    t('.created', returned: @uniform_return.returned_count, written_off: @uniform_return.written_off_count)
  end

  def uniform_return_params
    params.require(:uniform_return).permit(:performed_on, :comment,
                                           rows: %i[uniform_stock_id good unusable])
  end
end
