# frozen_string_literal: true

class PaymentTypesController < ApplicationController
  def index
    authorize PaymentType
    @payment_types = PaymentType.all
    respond_to do |format|
      format.html
      format.json { render json: @payment_types }
    end
  end

  def new
    @payment_type = authorize PaymentType.new
    respond_to do |format|
      format.html { render 'form' }
      format.json { render json: @payment_type }
    end
  end

  def edit
    @payment_type = find_record PaymentType

    respond_to do |format|
      format.html { render 'form' }
      format.json { render json: @payment_type }
    end
  end

  def create
    @payment_type = authorize PaymentType.new(payment_type_params)

    respond_to do |format|
      if @payment_type.save
        format.html { redirect_to payment_types_path, notice: t('payment_types.created') }
        format.json { render json: @payment_type, status: :created, location: @payment_type }
      else
        format.html { render 'form' }
        format.json { render json: @payment_type.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @payment_type = find_record PaymentType

    respond_to do |format|
      if @payment_type.update_attributes(params[:payment_type])
        format.html { redirect_to payment_types_path, notice: t('payment_types.updated') }
        format.json { head :no_content }
      else
        format.html { render 'form' }
        format.json { render json: @payment_type.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @payment_type = find_record PaymentType
    @payment_type.destroy

    respond_to do |format|
      format.html { redirect_to payment_types_url }
      format.json { head :no_content }
    end
  end

  def payment_type_params
    params.require(:payment_type)
          .permit(:kind, :name)
  end
end
