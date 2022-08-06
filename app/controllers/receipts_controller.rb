class ReceiptsController < ApplicationController
  before_action -> { authorize :receipt }

  def new; end

  def add_product; end

  def print
    respond_to do |format|
      format.pdf do
        render_receipt if params[:print_receipt].present?
        render_warranty if params[:print_warranty].present?
        render_sale_check if params[:print_sale_check].present?
      end
    end
  end

  private

  def render_receipt
    send_data document.receipt.render, filename: 'receipt.pdf', type: 'application/pdf', disposition: 'inline'
  end

  def render_warranty
    send_data document.warranty.render, filename: 'warranty.pdf', type: 'application/pdf', disposition: 'inline'
  end

  def render_sale_check
    sale_check = document.sale_check
    filepath = "#{Rails.root.to_s}/tmp/pdf/#{sale_check.filename}"
    sale_check.render_file filepath
    PrinterTools.print_file filepath, type: :sale_check, height: sale_check.page_height_mm, printer: current_department.printer
    send_data sale_check.render, filename: 'sale_check.pdf', type: 'application/pdf', disposition: 'inline'
  end

  def document
    @document ||= PrintReceipt.(current_user.department, params[:receipt].to_unsafe_h.deep_symbolize_keys)
  end
end