# frozen_string_literal: true

class PhoneLabelsController < ApplicationController
  def index
    authorize PhoneLabel
    load_phone_labels
    @phone_label = PhoneLabel.new
    render 'shared/show_modal_form'
  end

  def create
    @phone_label = authorize PhoneLabel.new(phone_label_params)
    @phone_label.save
    load_phone_labels
  end

  def destroy
    @phone_label = authorize PhoneLabel.find(params[:id])
    @phone_label.destroy
    load_phone_labels
  end

  private

  def load_phone_labels
    @phone_labels = PhoneLabel.order(:label)
  end

  def phone_label_params
    params.require(:phone_label).permit(:phone_number, :label)
  end
end
