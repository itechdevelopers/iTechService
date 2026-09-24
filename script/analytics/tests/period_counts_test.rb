# frozen_string_literal: true

require 'minitest/autorun'
require 'date'
require_relative '../../../app/services/activity_counts/period_counts'
PeriodCounts = ActivityCounts::PeriodCounts

class PeriodCountsTest < Minitest::Test
  def record(date, quantities)
    branches = quantities.map do |id, quantity|
      { id: id, name: id.to_s.upcase, quantity: quantity }
    end
    { date: date.iso8601, quantity: quantities.values.sum, branches: branches }
  end

  def days_between(first, last, quantity: 0)
    result = []
    date = Date.iso8601(first)
    ending = Date.iso8601(last)
    while date <= ending
      result << record(date, { 'a' => quantity })
      date += 1
    end
    result
  end

  def test_missing_days_are_not_treated_as_zero_but_loaded_zero_is_counted
    days = days_between('2022-01-01', '2022-12-31', quantity: 0)
    days.pop
    result = PeriodCounts.new(days: days, today: Date.new(2024, 6, 1), year: 2022).result
    assert_nil result[:quantity]
    refute result[:coverage_complete]
    assert_equal 1, result[:missing_days]

    complete = PeriodCounts.new(days: days + [record(Date.new(2022, 12, 31), { 'a' => 0 })],
                                today: Date.new(2024, 6, 1), year: 2022).result
    assert_equal 0, complete[:quantity]
    assert complete[:coverage_complete]
  end

  def test_leap_cutoff_maps_to_february_28_in_previous_nonleap_year
    days = days_between('2024-01-01', '2024-02-29', quantity: 1)
    days += days_between('2023-01-01', '2023-02-28', quantity: 2)
    result = PeriodCounts.new(days: days, today: Date.new(2024, 3, 1), year: 2024).result
    assert_equal 60, result[:quantity]
    assert_equal 118, result[:comparison][:previous_quantity]
    assert_in_delta(-49.1525423729, result[:comparison][:change_percent], 0.000001)
    assert_equal '2024-02-29', result[:through]
    assert_equal 29, result[:months][1][:quantity]
    assert result[:months][1][:period_closed]
  end

  def test_january_first_has_no_completed_current_year_period
    result = PeriodCounts.new(days: [], today: Date.new(2024, 1, 1)).result
    assert_nil result[:quantity]
    assert_nil result[:through]
    refute result[:coverage_complete]
    assert_equal 0, result[:missing_days]
    assert result[:months].all? { |month| month[:quantity].nil? && month[:through].nil? }
    assert result[:months].none? { |month| month[:period_closed] }
    assert_nil result[:comparison][:previous_quantity]
  end

  def test_branch_filter_uses_day_level_branch_values_and_absent_branch_as_zero
    days = [
      record(Date.new(2023, 1, 1), { 'a' => 3, 'b' => 2 }),
      record(Date.new(2023, 1, 2), { 'a' => 4 })
    ]
    result = PeriodCounts.new(days: days, today: Date.new(2023, 1, 3), year: 2023, branch_id: 'b').result
    assert_equal 2, result[:quantity]
    assert_equal 'b', result[:branch_id]
    assert_equal 1, result[:branches].length
  end

  def test_branch_filter_reports_only_selected_branch
    days = [record(Date.new(2022, 1, 1), { 'a' => 3, 'b' => 2 })]
    result = PeriodCounts.new(days: days, today: Date.new(2023, 1, 1), year: 2022, branch_id: 'b').result
    assert_equal ['b'], result[:branches].map { |branch| branch[:id] }
  end

  def test_partial_month_and_year_compare_matching_cutoff
    days = days_between('2023-01-01', '2023-06-15', quantity: 2)
    days += days_between('2022-01-01', '2022-06-15', quantity: 1)
    result = PeriodCounts.new(days: days, today: Date.new(2023, 6, 16), year: 2023).result
    assert_equal 332, result[:quantity]
    assert_equal 166, result[:comparison][:previous_quantity]
    assert_equal 62, result[:months][0][:quantity]
    assert_equal 30, result[:months][5][:quantity]
    assert_equal '2023-06-15', result[:months][5][:through]
    refute result[:months][5][:period_closed]
    assert_nil result[:months][6][:quantity]
    assert_equal 15, result[:months][5][:previous_quantity]
  end

  def test_zero_previous_quantity_has_nil_percentage
    days = [
      record(Date.new(2023, 1, 1), { 'a' => 0 }),
      record(Date.new(2024, 1, 1), { 'a' => 5 })
    ]
    result = PeriodCounts.new(days: days, today: Date.new(2024, 1, 2)).result
    assert_equal 0, result[:comparison][:previous_quantity]
    assert_nil result[:comparison][:change_percent]
  end

  def test_history_full_year_yoy_is_independent_of_selected_year
    days = days_between('2021-01-01', '2021-12-31', quantity: 1)
    days += days_between('2022-01-01', '2022-12-31', quantity: 2)
    result = PeriodCounts.new(days: days, today: Date.new(2024, 1, 3), year: 2020).result

    assert_equal (2019..2024).to_a, result[:history].map { |row| row[:year] }
    row = result[:history].find { |item| item[:year] == 2022 }
    assert_equal 730, row[:quantity]
    assert_equal 365, row[:previous_quantity]
    assert_equal 100.0, row[:change_percent]
    assert row[:period_closed]
  end

  def test_current_history_yoy_uses_the_same_date_in_the_previous_year
    days = days_between('2023-01-01', '2023-06-15', quantity: 1)
    days += days_between('2024-01-01', '2024-06-15', quantity: 2)
    result = PeriodCounts.new(days: days, today: Date.new(2024, 6, 16), year: 2020).result

    row = result[:history].find { |item| item[:year] == 2024 }
    assert_equal 334, row[:quantity]
    assert_equal 166, row[:previous_quantity]
    assert_in_delta 101.2048192771, row[:change_percent], 0.000001
    refute row[:period_closed]
  end

  def test_all_branch_totals_and_zero_previous_branch_quantities
    days = [
      record(Date.new(2023, 1, 1), { 'a' => 0, 'b' => 0 }),
      record(Date.new(2024, 1, 1), { 'a' => 5, 'b' => 7 })
    ]
    result = PeriodCounts.new(days: days, today: Date.new(2024, 1, 2)).result

    branches = result[:branches].each_with_object({}) { |branch, memo| memo[branch[:id]] = branch }
    assert_equal 12, result[:quantity]
    assert_equal 5, branches['a'][:quantity]
    assert_equal 7, branches['b'][:quantity]
    %w[a b].each do |id|
      assert_equal 0, branches[id][:previous_quantity]
      assert_nil branches[id][:change_percent]
    end
  end

  def test_rejects_malformed_and_inconsistent_source_data
    today = Date.new(2024, 6, 1)
    assert_raises(ArgumentError) { PeriodCounts.new(days: [{ date: '2024-02-30', quantity: 0, branches: [] }], today: today) }
    assert_raises(ArgumentError) { PeriodCounts.new(days: [record(Date.new(2024, 1, 1), { 'a' => 1 }), record(Date.new(2024, 1, 1), { 'a' => 1 })], today: today) }
    assert_raises(ArgumentError) { PeriodCounts.new(days: [{ date: '2024-01-01', quantity: -1, branches: [] }], today: today) }
    assert_raises(ArgumentError) do
      PeriodCounts.new(days: [{ date: '2024-01-01', quantity: 2,
                                branches: [{ id: 'a', name: 'A', quantity: 1 }] }], today: today)
    end
    assert_raises(ArgumentError) do
      PeriodCounts.new(days: [{ date: '2024-01-01', quantity: 2,
                                branches: [{ id: 'a', name: 'A', quantity: 1 },
                                           { id: 'a', name: 'A', quantity: 1 }] }], today: today)
    end
    assert_raises(ArgumentError) do
      PeriodCounts.new(days: [{ date: '2024-01-01', quantity: 0,
                                branches: [{ id: ' ', name: 'A', quantity: 0 }] }], today: today)
    end
    assert_raises(ArgumentError) { PeriodCounts.new(days: [], today: today, branch_id: ' ') }
    assert_raises(ArgumentError) { PeriodCounts.new(days: [], today: today, year: 2018) }
  end
end
