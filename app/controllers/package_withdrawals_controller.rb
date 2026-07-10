# frozen_string_literal: true

class PackageWithdrawalsController < ApplicationController
  def new
    @package_withdrawal = authorize PackageWithdrawal.new(withdrawn_on: Date.current)
    load_designs
  end

  def create
    @package_withdrawal = authorize PackageWithdrawal.new(package_withdrawal_params)
    @package_withdrawal.user = current_user # водитель — всегда текущий пользователь

    if @package_withdrawal.save
      redirect_to new_package_withdrawal_path, notice: t('.created')
    else
      load_designs
      render :new
    end
  end

  private

  # Для сгруппированной выпадашки: только дизайны, у которых есть строки-остатки.
  def load_designs
    @designs = PackageDesign.ordered.includes(:package_stocks).select do |design|
      design.package_stocks.any?
    end
  end

  def package_withdrawal_params
    params.require(:package_withdrawal)
          .permit(:package_stock_id, :boxes_count, :withdrawn_on, :reason)
  end
end
