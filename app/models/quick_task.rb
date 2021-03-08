# frozen_string_literal: true

class QuickTask < ActiveRecord::Base
  scope :name_asc, -> { order('name asc') }
  has_and_belongs_to_many :quick_orders
  validates_presence_of :name
end
