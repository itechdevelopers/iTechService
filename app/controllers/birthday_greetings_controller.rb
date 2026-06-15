# frozen_string_literal: true

# Синглтон-настройка поздравлений с ДР: одна строка на систему (BirthdayGreeting.instance),
# поэтому resource (а не resources) — только edit/update + тест-отправка send_now.
class BirthdayGreetingsController < ApplicationController
  before_action :set_greeting

  def edit
    authorize @birthday_greeting
    @birthday_greeting.variants.build if @birthday_greeting.variants.empty?
    @birthday_greeting.gifs.build if @birthday_greeting.gifs.empty?
  end

  def update
    authorize @birthday_greeting
    if @birthday_greeting.update(greeting_params)
      redirect_to edit_birthday_greeting_path, notice: t('.updated')
    else
      @birthday_greeting.variants.build if @birthday_greeting.variants.empty?
      @birthday_greeting.gifs.build if @birthday_greeting.gifs.empty?
      render :edit
    end
  end

  # Тест-отправка «прямо сейчас»: реально шлёт поздравления сегодняшним именинникам,
  # но НЕ трогает last_run_on (см. BirthdayGreeting#deliver_now!) — на расписание не влияет.
  def send_now
    authorize @birthday_greeting
    count = @birthday_greeting.deliver_now!
    if count.positive?
      redirect_to edit_birthday_greeting_path, notice: t('.sent', count: count)
    else
      redirect_to edit_birthday_greeting_path, alert: t('.no_celebrants')
    end
  end

  private

  def set_greeting
    @birthday_greeting = BirthdayGreeting.instance
  end

  def greeting_params
    params.require(:birthday_greeting).permit(
      :telegram_chat_id, :enabled, :send_gif,
      variants_attributes: %i[id body _destroy],
      gifs_attributes: %i[id file _destroy]
    )
  end
end
