# frozen_string_literal: true

class PackageWithdrawalsController < ApplicationController
  def new
    authorize PackageWithdrawal.new
    @batch = PackageWithdrawalBatch.new(withdrawn_on: Date.current)
    load_designs
  end

  def create
    authorize PackageWithdrawal.new
    @batch = PackageWithdrawalBatch.new(batch_params)
    @batch.user = current_user # водитель — всегда текущий пользователь

    if @batch.save
      redirect_to new_package_withdrawal_path,
                  notice: t('.created', count: @batch.withdrawals.size)
    else
      load_designs
      render :new
    end
  end

  private

  # Для формы: только дизайны, у которых есть строки-остатки (иначе выбирать нечего).
  def load_designs
    @designs = PackageDesign.ordered.includes(:package_stocks).select do |design|
      design.package_stocks.any?
    end
  end

  def batch_params
    params.require(:package_withdrawal_batch)
          .permit(:withdrawn_on, :reason, lines: %i[package_stock_id boxes_count])
  end
end
