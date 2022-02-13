class ProductImportsController < ApplicationController
  def new
    @product_import = authorize ProductImport.new
  end

  def create
    authorize ProductImport

    if action_params.dig(:product_import, :store_id).present?
      Delayed::Job.enqueue(ProductImportJob.new(params_for_job))
      redirect_to new_product_import_path, notice: 'Products import performed...'
    else
      redirect_to new_product_import_path, error: 'Store is not defined!!!'
    end
  end

  private

  def params_for_job
    if (import_params = action_params[:product_import]).present?
      [:file, :prices_file, :barcodes_file, :nomenclature_file].each do |f|
        import_params[f] = FileLoader.rename_uploaded_file(import_params[f]) if import_params[f].present?
      end
      import_params
    else
      {}
    end
  end
end
