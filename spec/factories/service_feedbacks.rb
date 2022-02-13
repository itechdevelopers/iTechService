FactoryBot.define do
  factory :service_feedback do
    service_job
    scheduled_on { "2018-01-29 23:25:53" }
    postponed_times { 1 }
    details { "MyText" }
  end
end
