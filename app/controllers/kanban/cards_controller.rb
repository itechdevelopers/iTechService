module Kanban
  class CardsController < ApplicationController
    before_action :set_card, only: %i[edit update destroy]

    def index
      @cards = Card.all
    end

    def show
      @card = authorize Card.unscoped.find_by(id: params[:id])
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
          send_mail_to_managers
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
      @card.archive!

      respond_to do |format|
        format.html { redirect_to kanban_board_url(@card.board), notice: t('.destroyed') }
        format.json { head :no_content }
      end
    end

    def unarchive
      @card = authorize Card.unscoped.find(params[:id])
      @card.unarchive!

      respond_to do |format|
        format.html { redirect_to kanban_board_url(@card.board), notice: t('.unarchived') }
      end
    end

    def update_card_columns
      authorize Card
      positioned_cards = JSON.parse(card_params[:cards_positions])
      ActiveRecord::Base.transaction do
        positioned_cards.each do |card|
          Card.find(card['id']).update(column_id: card['column_id'])
        end
      end
    end

    private

    def set_card
      @card = find_record(Card)
    end

    def card_params
      params.require(:kanban_card).permit(:content, :column_id, :deadline, :name, :cards_positions,
        manager_ids: [], photos: [])
    end

    def update_notifications
      @notifications.each do |notification|
        notification.update(url: kanban_card_url(@card), referenceable: @card)
        UserNotificationChannel.broadcast_to(notification.user, notification) unless notification.errors.any?
      end
    end

    def send_mail_to_managers
      manager_ids = @card.board.managers.pluck(:id)
      KanbanMailer.new_card_notification(manager_ids, @card.id).deliver_later if manager_ids.any?
    end
  end
end
