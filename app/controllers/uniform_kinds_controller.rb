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

  def uniform_kind_params
    params.require(:uniform_kind).permit(
      :name, :description, :cost, :image, :image_cache, :remove_image, sizes: []
    )
  end
end
