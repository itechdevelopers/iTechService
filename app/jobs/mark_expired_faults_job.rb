class MarkExpiredFaultsJob < ApplicationJob
  queue_as :default

  def perform
    MarkExpiredFaults.()
  end
end