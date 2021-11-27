# frozen_string_literal: true

class Carrier < ApplicationRecord
  default_scope { order('name asc') }
  validates_presence_of :name
end
