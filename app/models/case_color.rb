# frozen_string_literal: true

class CaseColor < ActiveRecord::Base
  default_scope { order('name asc') }
  scope :ordered_by_name, -> { order('name asc') }
  validates_presence_of :name
end
