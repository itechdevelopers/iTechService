module Kanban
  class CardsController < ApplicationController
    before_action :set_card, only: %i[show edit update destroy]

    def index
      @cards = Card.all
    end

    def show
    end

    def new
      @card = authorize Card.new(params.permit(:column_id))
    end

    def edit
    end

    def create
      @card = authorize Card.new(card_params)
      @card.author = current_user

      respond_to do |format|
        if @card.save
          update_notifications if @notifications&.any?
          format.html { redirect_to kanban_card_url(@card), notice: t('.created') }
          format.json { render :show, status: :created, location: @card }
        else
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: @card.errors, status: :unprocessable_entity }
        end
      end
    end

    def update
      respond_to do |format|
        if @card.update(card_params)
          format.html { redirect_to kanban_card_url(@card), notice: t('.updated') }
          format.json { render :show, status: :ok, location: @card }
        else
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: @card.errors, status: :unprocessable_entity }
        end
      end
    end

    def destroy
      @card.destroy

      respond_to do |format|
        format.html { redirect_to kanban_board_url(@card.board), notice: t('.destroyed') }
        format.json { head :no_content }
      end
    end

    private

    def set_card
      @card = find_record(Card)
    end

    def card_params
      params.require(:kanban_card).permit(:content, :column_id, :deadline, :name,
        manager_ids: [], photos: [])
    end

    def update_notifications
      @notifications.each do |notification|
        notification.update(url: kanban_card_url(@card), referenceable: @card)
        UserNotificationChannel.broadcast_to(notification.user, notification) unless notification.errors.any?
      end
    end
  end
end
