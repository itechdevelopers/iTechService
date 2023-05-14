module Kanban
  class ColumnsController < ApplicationController
    before_action :set_column, only: %i[edit update destroy]
    before_action :set_board, only: %i[new create]

    def new
      @column = authorize @board.columns.build
    end

    def edit
    end

    def create
      @column = authorize @board.columns.build(column_params)

      respond_to do |format|
        if @column.save
          format.html { redirect_to kanban_board_path(@column.board), notice: t('.created') }
          format.json { render :show, status: :created, location: @column }
        else
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: @column.errors, status: :unprocessable_entity }
        end
      end
    end

    def update
      respond_to do |format|
        if @column.update(column_params)
          format.html { redirect_to kanban_board_path(@column.board), notice: t('.updated') }
          format.json { render :show, status: :ok, location: @column }
        else
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: @column.errors, status: :unprocessable_entity }
        end
      end
    end

    def destroy
      @column.destroy

      respond_to do |format|
        format.html { redirect_to kanban_board_path(@column.board), notice: t('.destroyed') }
        format.json { head :no_content }
      end
    end

    private

    def set_board
      @board = Board.find(params[:board_id])
    end

    def set_column
      @column = find_record(Column)
    end

    def column_params
      params.require(:kanban_column).permit(:name, :position)
    end
  end
end
