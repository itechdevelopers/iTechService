# frozen_string_literal: true

module TimeBankHelper
  def format_time_bank_balance(total_minutes)
    TimeBankEntry.format_balance(total_minutes)
  end
end
