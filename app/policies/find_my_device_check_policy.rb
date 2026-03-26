# frozen_string_literal: true

class FindMyDeviceCheckPolicy < ApplicationPolicy
  def index?
    any_admin?
  end

  def check?
    true
  end

  def toggle?
    any_admin?
  end
end
