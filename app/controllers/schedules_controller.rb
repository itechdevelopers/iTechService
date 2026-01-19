# frozen_string_literal: true

class SchedulesController < ApplicationController
  def index
    authorize :schedule
  end
end
