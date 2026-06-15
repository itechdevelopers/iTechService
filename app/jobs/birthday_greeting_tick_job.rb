class BirthdayGreetingTickJob < ApplicationJob
  queue_as :default

  def perform
    BirthdayGreeting.deliver_today!
  end
end
