# frozen_string_literal: true

class StoreClosingNotificationPhrasesController < ApplicationController
  def index
    authorize :schedule
    load_phrases
    @phrase = StoreClosingNotificationPhrase.new
    render 'shared/show_modal_form'
  end

  def create
    authorize :schedule
    @phrase = StoreClosingNotificationPhrase.new(phrase_params)
    @phrase.save
    load_phrases
  end

  def update
    authorize :schedule
    @phrase = StoreClosingNotificationPhrase.find(params[:id])
    @phrase.update(phrase_params)
    load_phrases
  end

  def destroy
    authorize :schedule
    @phrase = StoreClosingNotificationPhrase.find(params[:id])
    @phrase.destroy
    load_phrases
  end

  private

  def load_phrases
    @phrases = StoreClosingNotificationPhrase.order(:id)
  end

  def phrase_params
    params.require(:store_closing_notification_phrase).permit(:text, :active)
  end
end
