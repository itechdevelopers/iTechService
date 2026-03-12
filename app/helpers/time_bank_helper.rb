# frozen_string_literal: true

module TimeBankHelper
  def format_time_bank_amount(days, minutes)
    TimeBankEntry.format_amount(days, minutes)
  end

  def format_time_bank_balance(days, minutes)
    TimeBankEntry.format_balance(days, minutes)
  end
end
