class TelegramBroadcastTickJob < ApplicationJob
  queue_as :default

  def perform
    TelegramBroadcast.deliver_due!
  end
end
