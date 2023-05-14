module Kanban
  class BoardsController < ApplicationController
    before_action :set_board, only: %i[edit update destroy]

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

    private

    def set_board
      @board = find_record Board
    end

    def board_params
      params.require(:kanban_board).permit(:name, :background)
    end
  end
end
