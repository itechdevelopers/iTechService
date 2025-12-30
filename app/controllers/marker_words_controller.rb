# frozen_string_literal: true

class MarkerWordsController < ApplicationController
  def index
    authorize MarkerWord
    load_marker_words
    @marker_word = MarkerWord.new
    render 'shared/show_modal_form'
  end

  def create
    @marker_word = authorize MarkerWord.new(marker_word_params)
    @marker_word.save
    load_marker_words
  end

  def destroy
    @marker_word = authorize MarkerWord.find(params[:id])
    @marker_word.destroy
    load_marker_words
  end

  private

  def load_marker_words
    @marker_words = MarkerWord.order(:word)
  end

  def marker_word_params
    params.require(:marker_word).permit(:word)
  end
end
