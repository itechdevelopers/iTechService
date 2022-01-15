class SalesImportsController < ApplicationController
  def new
    authorize SalesImport
    @sales_import = SalesImport.new
  end

  def create
    authorize SalesImport

    if params[:sales_import].present?
      file = FileLoader.rename_uploaded_file(action_params.dig(:sales_import, :file))
      SalesImportJob.perform_later file
      redirect_to new_sales_import_path, notice: t('imports.enqueued')
    else
      redirect_to new_sales_import_path, alert: 'Файл не найден!'
    end
  end
end
