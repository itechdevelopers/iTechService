# frozen_string_literal: true

# Выдача формы сотруднику. Отдельно от складских документов: здесь выбирается
# получатель, а позиции могут собираться сразу из нескольких видов формы.
class UniformIssuesController < ApplicationController
  def new
    @uniform_operation = authorize build_operation
    load_form_data
  end

  def create
    @uniform_operation = authorize build_operation(uniform_issue_params)

    if @uniform_operation.save
      redirect_to return_path, notice: t('.created', user: @uniform_operation.recipient.short_name)
    else
      load_form_data
      render :new
    end
  end

  private

  def build_operation(attrs = {})
    UniformOperation.new(attrs).tap do |operation|
      operation.kind = 'issue'
      operation.author = current_user
      operation.performed_on ||= Date.current
    end
  end

  def load_form_data
    @uniform_kinds = UniformKind.ordered.includes(:uniform_stocks).select { |kind| kind.uniform_stocks.any? }
    @form_lines = form_lines
    @return_kind_id = params[:uniform_kind_id].presence
  end

  # Строк столько, сколько всего размеров во всех видах: индекс сквозной, а вьюха
  # достаёт свою строку по размеру. Как и в складской форме, присланные строки
  # переиспользуем, чтобы после ошибки ничего из введённого не пропало.
  def form_lines
    submitted = @uniform_operation.uniform_operation_lines.index_by(&:uniform_stock_id)
    stocks = @uniform_kinds.flat_map { |kind| kind.uniform_stocks.to_a }
    stocks.each_with_index.each_with_object({}) do |(stock, index), lines|
      lines[stock.id] = [index, submitted[stock.id] || UniformOperationLine.new(uniform_stock: stock)]
    end
  end

  def return_path
    kind_id = params[:uniform_kind_id].presence
    kind_id ? uniform_kind_path(kind_id) : uniform_kinds_path
  end

  def uniform_issue_params
    params.require(:uniform_operation).permit(
      :recipient_id, :performed_on, :comment,
      uniform_operation_lines_attributes: %i[uniform_stock_id quantity]
    )
  end
end
