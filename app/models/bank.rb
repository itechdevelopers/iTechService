# frozen_string_literal: true

class Bank < ActiveRecord::Base
  validates_presence_of :name
end
