# frozen_string_literal: true

class DutyNotificationPhrasesController < ApplicationController
  def index
    authorize :schedule
    load_phrases
    @phrase = DutyNotificationPhrase.new
    render 'shared/show_modal_form'
  end

  def create
    authorize :schedule
    @phrase = DutyNotificationPhrase.new(phrase_params)
    @phrase.save
    load_phrases
  end

  def update
    authorize :schedule
    @phrase = DutyNotificationPhrase.find(params[:id])
    @phrase.update(phrase_params)
    load_phrases
  end

  def destroy
    authorize :schedule
    @phrase = DutyNotificationPhrase.find(params[:id])
    @phrase.destroy
    load_phrases
  end

  private

  def load_phrases
    @phrases = DutyNotificationPhrase.order(:id)
  end

  def phrase_params
    params.require(:duty_notification_phrase).permit(:text, :active)
  end
end
