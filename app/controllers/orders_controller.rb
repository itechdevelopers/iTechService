# frozen_string_literal: true

class OrdersController < ApplicationController
  helper_method :sort_column, :sort_direction
  skip_before_action :authenticate_user!, :set_current_user, only: :check_status
  skip_after_action :verify_authorized, only: %i[index check_status device_type_select]

  def index
    @orders = policy_scope(Order)

    @orders = if current_user.technician? || (params[:kind] == 'spare_parts')
                @orders.technician_orders
              elsif current_user.marketing? || (params[:kind] == 'not_spare_parts')
                @orders.marketing_orders
              else
                @orders
              end

    @orders = @orders.search(filter_params)
    @orders = @orders.preload(:department, :customer, :user)

    @orders = if params.key?(:sort) && params.key?(:direction)
                @orders.reorder("orders.#{sort_column} #{sort_direction}")
              else
                @orders.newest
              end

    @orders = @orders.page(params[:page]) if params[:status].present?

    respond_to do |format|
      format.html
      format.js
      format.json { render json: @orders }
    end
  end

  def show
    @order = find_record(Order.includes(:notes))

    respond_to do |format|
      format.html
      format.json { render json: @order }
      format.pdf do
        pdf = OrderPdf.new @order, view_context
        filename = "order_#{@order.number}.pdf"
        filepath = "#{Rails.root}/tmp/pdf/#{filename}"
        pdf.render_file filepath
        PrinterTools.print_file filepath, printer: current_department.printer
        send_data pdf.render, filename: filename, type: 'application/pdf', disposition: 'inline'
      end
    end
  end

  def new
    params = order_params rescue {}
    params.merge!(status: 'new')
    @order = authorize Order.new(params)

    respond_to do |format|
      format.html
      format.json { render json: @order }
    end
  end

  def edit
    @order = find_record Order
  end

  def create
    @order = authorize Order.new(order_params)

    respond_to do |format|
      if @order.save
        OrdersMailer.notice(@order.id).deliver_later
        format.html { redirect_to orders_url, notice: t('orders.created') }
        format.json { render json: @order, status: :created, location: @order }
      else
        format.html { render action: 'new' }
        format.json { render json: @order.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @order = find_record Order

    respond_to do |format|
      if @order.update_attributes(order_params)
        format.html { redirect_to orders_url, notice: t('orders.updated') }
        format.json { head :no_content }
        format.js
      else
        format.html { render action: 'edit' }
        format.json { render json: @order.errors, status: :unprocessable_entity }
        format.js
      end
    end
  end

  def destroy
    @order = find_record Order
    @order.destroy

    respond_to do |format|
      format.html { redirect_to orders_url }
      format.json { head :no_content }
    end
  end

  def change_status
    @order = find_record Order

    respond_to do |format|
      if @order.update_attributes(order_change_status_params)
        format.js
      else
        format.js
      end
    end
  end

  private

  def history
    order = find_record Order
    @records = order.history_records
    render 'shared/show_history'
  end

  def check_status
    @order = policy_scope(Order).find_by_number(params[:ticket_number])

    respond_to do |format|
      if @order.present?
        format.js { render 'information' }
        format.json { render text: "orderStatus({'status':'#{@order.status_for_client}'})" }
      else
        format.js { render t('orders.not_found') }
        format.json { render js: "orderStatus({'status':'not_found'})" }
      end
    end
  end

  def device_type_select
    if params[:device_type_id].blank?
      render 'device_type_refresh'
    else
      @device_type = DeviceType.find(params[:device_type_id])
      render 'device_type_select'
    end
  end

  private

  def sort_column
    Order.column_names.include?(params[:sort]) ? params[:sort] : ''
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : ''
  end

  # @return [Hash]
  def filter_params
    filter = params.permit(filter: [:order_number, :object_kind,
                                    :object, :customer, :user,
                                    { statuses: [], department_ids: [] }])[:filter] || { department_ids: [],
                                                                                         statuses: [] }
    filter.tap do |p|
      p[:department_ids].reject! { |e| e.to_s.empty? }
      p[:statuses].reject! { |e| e.to_s.empty? }
      if request.format.html?
        p[:department_ids] = [current_department&.id] if p[:department_ids].blank? && current_department
        p[:statuses] = %w[new done] if p[:statuses].blank?
      end
    end
  end

  def order_params
    params.require(:order)
          .permit(:approximate_price, :comment, :customer_id, :customer_type, :department_id, :desired_date, :model, :number, :object, :object_kind, :object_url, :payment_method, :picture, :prepayment, :priority, :quantity, :status, :user_comment, :user_id)
  end

  def order_change_status_params
    params.require(:order).permit(:status)
  end
end
