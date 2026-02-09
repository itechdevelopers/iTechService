# frozen_string_literal: true

class ScheduleWeekMemosController < ApplicationController
  before_action :set_schedule_group
  before_action :set_memo, only: %i[update destroy]

  def create
    authorize :schedule, :create_memo?
    @memo = @schedule_group.schedule_week_memos.build(memo_params)
    @memo.position = next_position
    @memo.save
  end

  def update
    authorize :schedule, :update_memo?
    @memo.update(memo_params)
  end

  def destroy
    authorize :schedule, :destroy_memo?
    @memo.destroy
  end

  private

  def set_schedule_group
    @schedule_group = ScheduleGroup.find(params[:schedule_group_id])
  end

  def set_memo
    @memo = @schedule_group.schedule_week_memos.find(params[:id])
  end

  def memo_params
    params.require(:schedule_week_memo).permit(:content, :week_start)
  end

  def next_position
    @schedule_group.schedule_week_memos
                   .where(week_start: memo_params[:week_start])
                   .maximum(:position).to_i + 1
  end
end
