class QuickOrdersController < ApplicationController
  def index
    authorize QuickOrder
    @quick_orders = policy_scope(QuickOrder)

    if params[:done].eql? 'true' #and current_user.any_admin?
      @quick_orders = @quick_orders.done
    # else
    #   @quick_orders = policy_scope(QuickOrder).in_month.undone
    end

    if params[:department_id].present? && can?(:view_everywhere, QuickOrder)
      @quick_orders = @quick_orders.in_department(params[:department_id])
    end

    @quick_orders = QuickOrderFilter.call(collection: @quick_orders, **filter_params).collection

    @quick_orders = @quick_orders.search(params).created_desc.page(params[:page])

    respond_to do |format|
      format.html # index.html.erb
      format.js { render 'shared/index', locals: { resource_table_id: 'quick_orders_table' } }
    end
  end

  def show
    @quick_order = find_record QuickOrder.includes(comments: :user)

    respond_to do |format|
      format.html # show.html.erb
      format.pdf do
        filename = "quick_order_#{@quick_order.number}.pdf"
        pdf = QuickOrderPdf.new @quick_order
        print_ticket(pdf, filename) if params[:print]
        send_data pdf.render, filename: filename, type: 'application/pdf', disposition: 'inline'
      end
    end
  end

  def new
    @quick_order = authorize QuickOrder.new

    respond_to do |format|
      format.html { render 'form' }
    end
  end

  def edit
    @quick_order = find_record QuickOrder

    respond_to do |format|
      format.html { render 'form' }
    end
  end

  def create
    @quick_order = authorize QuickOrder.new(params[:quick_order])

    respond_to do |format|
      if @quick_order.save
        filename = "quick_order_#{@quick_order.number}.pdf"
        pdf = QuickOrderPdf.new @quick_order
        print_ticket(pdf, filename)
        format.html { redirect_to quick_orders_path, notice: t('quick_orders.created') }
      else
        format.html { render 'form' }
      end
    end
  end

  def update
    @quick_order = find_record QuickOrder

    respond_to do |format|
      if @quick_order.update_attributes(params[:quick_order])
        format.html { redirect_to quick_orders_path, notice: t('quick_orders.updated') }
      else
        format.html { render 'form' }
      end
    end
  end

  def set_done
    @quick_order = find_record QuickOrder

    respond_to do |format|
      if @quick_order.set_done
        format.html { redirect_to quick_orders_path, notice: t('quick_orders.updated') }
        format.js
      else
        format.html { render 'form' }
        format.js { render nothing: true }
      end
    end
  end

  def destroy
    @quick_order = find_record QuickOrder
    @quick_order.destroy

    respond_to do |format|
      format.html { redirect_to quick_orders_url }
    end
  end

  def history
    quick_order = find_record QuickOrder
    @records = quick_order.history_records
    render 'shared/show_history'
  end

  private

  def print_ticket(pdf, filename)
    filepath = "#{Rails.root.to_s}/tmp/pdf/#{filename}"
    pdf.render_file filepath
    PrinterTools.print_file filepath, type: :quick_order, printer: current_department.printer
  end
end
