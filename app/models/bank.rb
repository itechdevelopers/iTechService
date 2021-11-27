# frozen_string_literal: true

class Bank < ApplicationRecord
  validates_presence_of :name
end
