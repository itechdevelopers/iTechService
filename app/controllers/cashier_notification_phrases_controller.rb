# frozen_string_literal: true

class CashierNotificationPhrasesController < ApplicationController
  def index
    authorize :schedule
    load_phrases
    @phrase = CashierNotificationPhrase.new
    render 'shared/show_modal_form'
  end

  def create
    authorize :schedule
    @phrase = CashierNotificationPhrase.new(phrase_params)
    @phrase.save
    load_phrases
  end

  def update
    authorize :schedule
    @phrase = CashierNotificationPhrase.find(params[:id])
    @phrase.update(phrase_params)
    load_phrases
  end

  def destroy
    authorize :schedule
    @phrase = CashierNotificationPhrase.find(params[:id])
    @phrase.destroy
    load_phrases
  end

  private

  def load_phrases
    @phrases = CashierNotificationPhrase.order(:id)
  end

  def phrase_params
    params.require(:cashier_notification_phrase).permit(:text, :active)
  end
end
