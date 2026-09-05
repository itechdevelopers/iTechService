# frozen_string_literal: true

class UniformKindsController < ApplicationController
  def index
    authorize UniformKind
    @uniform_kinds = UniformKind.ordered.includes(:uniform_stocks)
  end

  def show
    @uniform_kind = find_record UniformKind
    @stock_ids = @uniform_kind.uniform_stocks.map(&:id)
    lines = UniformOperationLine.for_stocks(@stock_ids)
    @on_employees = lines.holder_balance_by_stock
    @written_off = lines.quantity_by_stock(UniformOperation::WRITE_OFF_KINDS)
    @operations = UniformOperation
                  .joins(:uniform_operation_lines)
                  .where(uniform_operation_lines: { uniform_stock_id: @stock_ids })
                  .distinct.recent.limit(100)
                  .includes(:author, :recipient, uniform_operation_lines: :uniform_stock)
  end

  def report
    authorize UniformKind
    @uniform_kinds = UniformKind.ordered.includes(:uniform_stocks)
    @stocks = @uniform_kinds.flat_map { |kind| kind.uniform_stocks.to_a }
    @sizes = UniformKind::SIZES & @stocks.map(&:size)

    lines = UniformOperationLine.for_stocks(@stocks.map(&:id))
    @on_employees = lines.holder_balance_by_stock
    @written_off = lines.quantity_by_stock(UniformOperation::WRITE_OFF_KINDS)
    @holders = holders_breakdown
    @write_offs = UniformOperation.of_kind(UniformOperation::WRITE_OFF_KINDS).recent.limit(100)
                                  .includes(:author, :recipient, uniform_operation_lines: { uniform_stock: :uniform_kind })
  end

  def new
    @uniform_kind = authorize UniformKind.new
  end

  def create
    @uniform_kind = authorize UniformKind.new(uniform_kind_params)

    if @uniform_kind.save
      redirect_to uniform_kinds_path, notice: t('.created')
    else
      render :new
    end
  end

  def edit
    @uniform_kind = find_record UniformKind
  end

  def update
    @uniform_kind = find_record UniformKind

    if @uniform_kind.update(uniform_kind_params)
      redirect_to uniform_kinds_path, notice: t('.updated')
    else
      render :edit
    end
  end

  def destroy
    @uniform_kind = find_record UniformKind

    if @uniform_kind.destroy
      redirect_to uniform_kinds_path, notice: t('.destroyed')
    else
      redirect_to uniform_kinds_path, alert: @uniform_kind.errors.full_messages.to_sentence
    end
  end

  private

  # «У кого что на руках»: баланс по паре «сотрудник + позиция», разложенный по
  # сотрудникам. Нули отбрасываем — вернувший всё сотрудник в отчёте не нужен.
  def holders_breakdown
    stocks = @stocks.index_by(&:id)
    balances = UniformOperationLine.holder_balance_by_user_and_stock
                                   .reject { |(_user_id, stock_id), quantity| quantity.to_i.zero? || stocks[stock_id].nil? }
    users = User.where(id: balances.keys.map(&:first).uniq).index_by(&:id)

    balances.group_by { |(user_id, _stock_id), _quantity| users[user_id] }
            .reject { |user, _rows| user.nil? }
            .map { |user, rows| [user, rows.map { |(_user_id, stock_id), quantity| [stocks[stock_id], quantity] }] }
            .sort_by { |user, _rows| user.short_name.to_s }
  end

  def uniform_kind_params
    params.require(:uniform_kind).permit(
      :name, :description, :cost, :image, :image_cache, :remove_image, sizes: []
    )
  end
end
