module Kanban
  class BoardsController < ApplicationController
    before_action :set_board, only: %i[edit update destroy sorted archived]

    def index
      authorize Board
      @boards = Board.order(:id)
    end

    def show
      @board = find_record(Board.includes(columns: :cards))
    end

    def new
      @board = authorize Board.new
    end

    def edit
    end

    def create
      @board = authorize Board.new(board_params)

      respond_to do |format|
        if @board.save
          format.html { redirect_to kanban_board_url(@board), notice: t('.created') }
          format.json { render :show, status: :created, location: @board }
        else
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: @board.errors, status: :unprocessable_entity }
        end
      end
    end

    def update
      respond_to do |format|
        if @board.update(board_params)
          format.html { redirect_to kanban_board_url(@board), notice: t('.updated') }
          format.json { render :show, status: :ok, location: @board }
        else
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: @board.errors, status: :unprocessable_entity }
        end
      end
    end

    def destroy
      @board.destroy

      respond_to do |format|
        format.html { redirect_to kanban_boards_url, notice: t('.destroyed') }
        format.json { head :no_content }
      end
    end

    def sorted
      authorize Board
      sort_type = params[:sort_order] || "classic"
      @rendered_columns = @board.columns.map do |column|
        render_to_string(partial: "kanban/cards/card_in_column", collection: sorted_columns(column.cards, sort_type), as: :card)
      end
      respond_to do |format|
        format.js
      end
    end

    def archived
      @archived_cards = @board.archived_cards
    end

    private

    def set_board
      @board = find_record Board
    end

    def sorted_columns(columns, sort_type)
      columns.send(sort_type)
    end

    def board_params
      params.require(:kanban_board).permit(:name, :background, :sort_order, :open_background_color, :card_font_color,
                                           :open_card_font_size, :card_font_size,
                                           manager_ids: [], allowed_user_ids: [])
    end
  end
end
