# frozen_string_literal: true

# Складские документы по одному виду формы: приход и списание. Выдача сотруднику
# сюда не попадает — она выбирает получателя и может собрать несколько видов сразу.
class UniformOperationsController < ApplicationController
  WAREHOUSE_KINDS = %w[receipt write_off].freeze

  before_action :set_uniform_kind
  before_action :set_operation_kind

  def new
    @uniform_operation = authorize build_operation
    build_form_lines
  end

  def create
    @uniform_operation = authorize build_operation(uniform_operation_params)

    if @uniform_operation.save
      redirect_to uniform_kind_path(@uniform_kind), notice: t(".created_#{@operation_kind}")
    else
      build_form_lines
      render :new
    end
  end

  private

  def set_uniform_kind
    @uniform_kind = UniformKind.find(params[:uniform_kind_id])
  end

  def set_operation_kind
    @operation_kind = params[:kind].presence || params.dig(:uniform_operation, :kind)
    return if WAREHOUSE_KINDS.include?(@operation_kind)

    redirect_to uniform_kind_path(@uniform_kind), alert: t('uniform_operations.unknown_kind')
  end

  def build_operation(attrs = {})
    UniformOperation.new(attrs).tap do |operation|
      operation.kind = @operation_kind
      operation.author = current_user
      operation.performed_on ||= Date.current
    end
  end

  # Форма показывает строку на каждый размер вида, но нулевые строки отсеиваются
  # ещё при присваивании (reject_if), поэтому после неудачного сохранения размеры
  # без количества пропали бы из формы. Собираем список заново: присланную строку
  # берём как есть, недостающую достраиваем пустой — и всё в порядке размеров.
  def build_form_lines
    submitted = @uniform_operation.uniform_operation_lines.index_by(&:uniform_stock_id)
    @form_lines = @uniform_kind.uniform_stocks.map do |stock|
      submitted[stock.id] || UniformOperationLine.new(uniform_stock: stock)
    end
  end

  def uniform_operation_params
    params.require(:uniform_operation).permit(
      :kind, :performed_on, :comment,
      uniform_operation_lines_attributes: %i[uniform_stock_id quantity]
    )
  end
end
