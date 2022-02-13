FactoryBot.define do
  factory :service_free_job, class: 'Service::FreeJob' do
    performer { nil }
    client { nil }
    task { nil }
    comment { "MyText" }
  end
end
