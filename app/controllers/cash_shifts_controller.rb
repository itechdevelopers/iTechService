# frozen_string_literal: true

class CashShiftsController < ApplicationController
  def show
    @cash_shift = find_record CashShift
    respond_to do |format|
      format.pdf do
        pdf = CashShiftPdf.new @cash_shift, view_context
        filename = "cash_shift_#{@cash_shift.id}.pdf"
        send_data pdf.render, filename: filename, type: 'application/pdf', disposition: 'inline'
      end
    end
  end

  def close
    @cash_shift = find_record CashShift
    if @cash_shift.close
      redirect_to cash_shift_path(@cash_shift, format: :pdf)
    else
      redirect_to cash_drawer_path(@cash_shift.cash_drawer)
    end
  end

  def cash_shift_params
    params.require(:cash_shift)
          .permit(:cash_drawer_id, :closed_at, :is_closed, :user_id)
  end
end
