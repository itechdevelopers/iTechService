class AddDeductionActToBreakageReports < ActiveRecord::Migration[5.1]
  def change
    add_reference :breakage_reports, :deduction_act, foreign_key: true, index: true
  end
end
