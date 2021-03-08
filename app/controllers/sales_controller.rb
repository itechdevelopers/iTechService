# frozen_string_literal: true

class SalesController < ApplicationController
  helper_method :sort_column, :sort_direction

  def index
    authorize Sale
    @sales = policy_scope(Sale).search(params).reorder("#{sort_column} #{sort_direction}").page(params[:page])

    respond_to do |format|
      format.html
      format.json { render json: @sales }
      format.js { render(params[:form_name].present? ? 'shared/show_modal_form' : 'shared/index') }
    end
  end

  def show
    @sale = find_record Sale
    respond_to do |format|
      format.html
      format.json { render json: @sale }
      format.pdf do
        if Setting.print_sale_check? && can?(:print_check, @sale)
          pdf = SaleCheckPdf.new @sale, params[:copy].present?
          filename = "sale_check_#{@sale.id}.pdf"
          send_data pdf.render, filename: filename, type: 'application/pdf', disposition: 'inline'
        else
          render nothing: true
        end
      end
    end
  end

  def new
    @sale = authorize Sale.new(sale_params)
    load_top_salables
    respond_to do |format|
      format.html { render 'form' }
    end
  end

  def edit
    @sale = find_record Sale
    load_top_salables
    if can? :edit, @sale
      respond_to do |format|
        format.html { render 'form' }
        format.js { render 'shared/show_modal_form' }
      end
    else
      redirect_back_or @sale
    end
  end

  def create
    @sale = authorize Sale.new(sale_params)
    respond_to do |format|
      if @sale.save
        format.html { redirect_back_or root_path, notice: t('sales.created') }
        format.js { render 'save' }
      else
        load_top_salables
        format.html { render 'form' }
        format.js { flash.now[:error] = @sale.errors.full_messages; render 'save' }
      end
    end
  end

  def update
    @sale = find_record Sale
    respond_to do |format|
      if @sale.update_attributes params[:sale]
        format.html { redirect_back_or root_path, notice: t('sales.updated') }
        format.js { render 'save' }
      else
        load_top_salables
        format.html { render 'form' }
        format.js do
          flash.now[:error] = @sale.errors.full_messages
          params[:sale][:payments_attributes].present? or params[:sale][:sale_items_attributes].present? ? render('shared/show_modal_form') : render('save')
        end
      end
    end
  end

  def destroy
    @sale = find_record Sale
    @sale.set_deleted
    respond_to do |format|
      format.html { redirect_to sales_url }
    end
  end

  def post
    @sale = find_record Sale
    respond_to do |format|
      if @sale.post

        if Setting.print_sale_check?
          pdf = SaleCheckPdf.new @sale, params[:copy].present?
          filename = "sale_check_#{@sale.id}.pdf"
          filepath = "#{Rails.root}/tmp/pdf/#{filename}"
          pdf.render_file filepath
          PrinterTools.print_file filepath, type: :sale_check, height: pdf.page_height_mm,
                                            printer: current_department.printer
        end

        message = 'Продажа проведена.'

        if @sale.service_job.present?
          @sale.service_job.archive
          message += ' Устройство переведено в архив.'
        end

        format.html { redirect_to new_sale_path, notice: message }
      else
        load_top_salables
        flash.alert = @sale.errors.full_messages
        format.html { render 'form', error: t('documents.not_posted') }
      end
    end
  end

  def cancel
    @sale = find_record Sale
    @sale.cancel
    respond_to do |format|
      format.html { redirect_to new_sale_path }
    end
  end

  def print_check
    if Setting.print_sale_check?
      @sale = find_record Sale
      pdf = if can?(:reprint_check, @sale)
              SaleCheckPdf.new @sale, params[:copy].present?
            else
              SaleCheckPdf.new @sale, true
            end
      filepath = "#{Rails.root}/tmp/pdf/sale_check_#{@sale.id}.pdf"
      pdf.render_file filepath
      PrinterTools.print_file filepath, type: :sale_check, height: pdf.page_height_mm,
                                        printer: current_department.printer
      message = 'Чек отправлен на печать.'
    else
      message = 'Печать чеков продаж отключена.'
    end

    respond_to do |format|
      format.html { redirect_to new_sale_path, notice: message }
      format.js { render_error message }
    end
  end

  def print_warranty
    @sale = find_record Sale
    pdf = WarrantyPdf.new @sale
    filename = "sale_warranty_#{@sale.id}.pdf"
    respond_to do |format|
      format.pdf { send_data pdf.render, filename: filename, type: 'application/pdf', disposition: 'inline' }
    end
  end

  def return_check
    source_sale = find_record Sale
    @sale = source_sale.build_return
    @sale.save
    respond_to do |format|
      format.html { redirect_to edit_sale_path(@sale) }
    end
  end

  def attach_gift_certificate
    @sale = find_record Sale
    @sale.attach_gift_certificate(params[:number])
    render 'save'
  end

  private

  def sort_column
    Sale.column_names.include?(params[:sort]) ? params[:sort] : 'date'
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : 'desc'
  end

  def load_top_salables
    @top_salables = TopSalable.roots.ordered
  end

  def sale_params
    params.require(:sale)
          .permit(:cash_shift_id, :client_id, :date, :is_return, :status, :store_id, :user_id,
                    sale_items: [:sale_id, :item_id, :price, :quantity, :discount, :device_task_id],
                    payments: [:value, :kind, :sale_id, :bank_id, :gift_certificate_id, :device_name,
                               :device_number, :client_info, :appraiser, :device_logout]
                  )
    # TODO: check nested attributes for: sale_items, payments
  end
end
