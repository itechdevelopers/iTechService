# frozen_string_literal: true

class PaymentsController < ApplicationController
  def index
    skip_authorization
    @sale = find_sale
    @payments = @sale.payments
    params[:form_name] = 'payments/modal_index'
    respond_to do |format|
      format.html
      format.js { render 'shared/show_modal_form' }
    end
  end

  def show
    @payment = find_record Payment
    respond_to do |format|
      format.html
    end
  end

  def new
    @sale = find_sale
    @payment = authorize Payment.new(payment_params)
    respond_to do |format|
      format.html { render 'form' }
      format.js { render 'shared/show_modal_form' }
    end
  end

  def edit
    @sale = find_sale
    @payment = find_record Payment
    respond_to do |format|
      format.html { render 'form' }
    end
  end

  def create
    @sale = find_sale
    payment = authorize Payment.new(payment_params)
    outcome = Sales::AddPayment.run(sale: @sale, payment: payment)
    @payment = outcome.result

    respond_to do |format|
      if outcome.valid?
        format.html { redirect_to @payment, notice: 'Оплата создана.' }
        format.js { render 'save' }
      else
        format.html { render 'form' }
        format.js { render 'shared/show_modal_form' }
      end
    end
  end

  def update
    @sale = find_sale
    @payment = find_record Payment
    respond_to do |format|
      if @payment.update_attributes(payment_params)
        format.html { redirect_to @payment, notice: 'Payment was successfully updated.' }
        format.js { render 'save' }
      else
        format.html { render 'form' }
        format.js { render 'shared/show_modal_form' }
      end
    end
  end

  def destroy
    @payment = find_record Payment
    @payment.destroy
    respond_to do |format|
      format.html { redirect_to payments_url }
    end
  end

  private

  def find_sale
    policy_scope(Sale).find(params[:sale_id])
  end

  def payment_params
    params.require(:payment)
          .permit(:appraiser, :bank_id, :client_info, :device_name, :device_number, :gift_certificate_id, :kind, :sale_id, :value)
  end
end
