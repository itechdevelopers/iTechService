# frozen_string_literal: true

class PackageDesignsController < ApplicationController
  # Read-only «табличка» пакетов для админа (просмотр остатков).
  def index
    authorize PackageDesign
    @package_designs =
      PackageDesign.ordered.includes(:package_stocks)
    # История заборов: что/сколько/кто/когда. Ограничиваем последними 100,
    # чтобы страница не разрасталась (полный журнал — задел на будущее).
    @package_withdrawals =
      PackageWithdrawal.recent.includes(:user, package_stock: :package_design).limit(100)
  end

  def new
    @package_design = authorize PackageDesign.new
    ensure_one_size_row(@package_design)
  end

  def create
    @package_design = authorize PackageDesign.new(package_design_params)

    if @package_design.save
      redirect_to package_designs_path, notice: t('.created')
    else
      ensure_one_size_row(@package_design)
      render :new
    end
  end

  def edit
    @package_design = find_record PackageDesign
    ensure_one_size_row(@package_design)
  end

  def update
    @package_design = find_record PackageDesign

    if @package_design.update(package_design_params)
      redirect_to package_designs_path, notice: t('.updated')
    else
      ensure_one_size_row(@package_design)
      render :edit
    end
  end

  def destroy
    @package_design = find_record PackageDesign
    @package_design.destroy
    redirect_to package_designs_path, notice: t('.destroyed')
  end

  private

  # Форма стартует минимум с одной пустой строки размера; остальные админ
  # добавляет кнопкой «Добавить размер» (link_to_add_fields).
  def ensure_one_size_row(design)
    design.package_stocks.build if design.package_stocks.empty?
  end

  def package_design_params
    params.require(:package_design).permit(
      :name, :image, :image_cache, :remove_image,
      package_stocks_attributes: %i[id size boxes_count per_box_count low_stock_threshold _destroy]
    )
  end
end
