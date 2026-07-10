# frozen_string_literal: true

class PackageDesignsController < ApplicationController
  # Цикл 1: read-only «табличка» пакетов для админа (просмотр остатков).
  # CRUD дизайнов/остатков добавится в Цикле 2.
  def index
    authorize PackageDesign
    @package_designs =
      PackageDesign.ordered.includes(:package_stocks)
  end
end
