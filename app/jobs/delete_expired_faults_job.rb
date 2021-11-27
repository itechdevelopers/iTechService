class DeleteExpiredFaultsJob < ApplicationJob
  queue_as :default

  def perform
    DeleteExpiredFaults.()
  end
end