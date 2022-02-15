# frozen_string_literal: true

class TradeInDevicesController < ApplicationController
  skip_after_action :verify_authorized
  respond_to :html

  def index
    respond_to do |format|
      run TradeInDevice::Index do |result|
        format.html { return render_cell TradeInDevice::Cell::Index, context: { policy: result['policy.default'] } }
        format.js do
          content = cell(TradeInDevice::Cell::Table, result['model'],
                         context: { policy: result['policy.default'] }).call
          render 'index', locals: { content: content }
        end
      end
      format.any(:html, :js) { failed }
    end
  end

  def purgatory
    authorize TradeInDevice, :index_unconfirmed?
    trade_in_devices = TradeInDevice.unconfirmed
    the_policy = policy(TradeInDevice)

    respond_to do |format|
      format.html do
        render_cell(TradeInDevice::Cell::Purgatory, model: trade_in_devices, context: { policy: the_policy })
      end
    end
  end

  def show
    run TradeInDevice::Show do
      return render_cell TradeInDevice::Cell::Show
    end
    failed
  end

  # TODO: make it via ajax
  def print
    trade_in_device = find_record TradeInDevice
    pdf = print_ticket trade_in_device
    send_data pdf.render, filename: pdf.filename, type: 'application/pdf', disposition: :inline
  end

  def new
    run TradeInDevice::Create::Present do
      return render_form
    end
    failed
  end

  def create
    run TradeInDevice::Create do
      print_ticket @model
      return redirect_to trade_in_device_path(@model.id), notice: operation_message
    end
    flash.now.alert = operation_message
    render_form
  end

  def edit
    run TradeInDevice::Update::Present do
      return render_form
    end
    failed
  end

  def update
    run TradeInDevice::Update, update_trade_in_device_params do
      return redirect_to_index notice: operation_message
    end
    render_form
  end

  def destroy
    run TradeInDevice::Destroy do
      return redirect_to trade_in_devices_url, notice: operation_message
    end
    failed
  end

  private

  def render_form
    render_cell TradeInDevice::Cell::Form
  end

  def print_ticket(trade_in_device)
    pdf = TradeInDevicePdf.new(trade_in_device)
    pdf.render_file
    PrintFile.call(pdf.filepath, type: :trade_in, printer: current_user.department.printer)
    pdf
  end

  def trade_in_device_params
    params.require(:trade_in_device)
          .permit(:apple_guarantee, :appraised_value, :appraiser, :archived, :archiving_comment, :bought_device, :check_icloud, :client_id, :client_name, :client_phone, :condition, :confirmed, :department_id, :equipment, :extended_guarantee, :item_id, :number, :received_at, :receiver_id, :replacement_status, :sale_amount)
  end

  def update_trade_in_device_params
    {
      id: params[:id],
      trade_in_device: params.require(:trade_in_device).permit(permitted_update_attributes)
    }
  end

  def permitted_update_attributes
    if policy(TradeInDevice).manage?
      [:apple_guarantee, :appraised_value, :appraiser, :archived, :archiving_comment, :bought_device, :check_icloud, :client_id, :client_name, :client_phone, :condition, :confirmed, :department_id, :equipment, :extended_guarantee, :item_id, :number, :received_at, :receiver_id, :replacement_status, :sale_amount]
    else
      [:apple_guarantee]
    end
  end
end
