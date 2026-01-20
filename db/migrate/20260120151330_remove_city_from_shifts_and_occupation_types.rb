# frozen_string_literal: true

class RemoveCityFromShiftsAndOccupationTypes < ActiveRecord::Migration[5.1]
  def change
    remove_reference :shifts, :city, foreign_key: true
    remove_reference :occupation_types, :city, foreign_key: true
  end
end
