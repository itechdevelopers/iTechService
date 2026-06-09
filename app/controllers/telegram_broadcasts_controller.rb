# frozen_string_literal: true

class TelegramBroadcastsController < ApplicationController
  before_action :set_broadcast, only: %i[edit update destroy send_now]

  def index
    authorize TelegramBroadcast
    @telegram_broadcasts = TelegramBroadcast.includes(:telegram_chat, :variants).order(:title)
  end

  def new
    authorize TelegramBroadcast
    @telegram_broadcast = TelegramBroadcast.new
    @telegram_broadcast.variants.build
  end

  def create
    authorize TelegramBroadcast
    @telegram_broadcast = TelegramBroadcast.new(broadcast_params)
    if @telegram_broadcast.save
      redirect_to telegram_broadcasts_path, notice: t('.created')
    else
      @telegram_broadcast.variants.build if @telegram_broadcast.variants.empty?
      render :new
    end
  end

  def edit
    authorize @telegram_broadcast
    @telegram_broadcast.variants.build if @telegram_broadcast.variants.empty?
  end

  def update
    authorize @telegram_broadcast
    if @telegram_broadcast.update(broadcast_params)
      redirect_to telegram_broadcasts_path, notice: t('.updated')
    else
      @telegram_broadcast.variants.build if @telegram_broadcast.variants.empty?
      render :edit
    end
  end

  def destroy
    authorize @telegram_broadcast
    @telegram_broadcast.destroy
    redirect_to telegram_broadcasts_path, notice: t('.destroyed')
  end

  # Тест-отправка «прямо сейчас» — реально шлёт в группу, но не помечает
  # рассылку отправленной (см. TelegramBroadcast#deliver_now!).
  def send_now
    authorize @telegram_broadcast
    if @telegram_broadcast.deliver_now!
      redirect_to telegram_broadcasts_path, notice: t('.sent')
    else
      redirect_to telegram_broadcasts_path, alert: t('.send_failed')
    end
  end

  private

  def set_broadcast
    @telegram_broadcast = TelegramBroadcast.find(params[:id])
  end

  def broadcast_params
    params.require(:telegram_broadcast).permit(
      :telegram_chat_id, :title, :schedule_type, :day_of_month, :interval_days,
      :selection_mode, :active, :image, :remove_image,
      variants_attributes: %i[id body _destroy]
    )
  end
end
