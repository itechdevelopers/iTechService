FactoryBot.define do
  factory :timesheet_day do
    date { '2013-07-01' }
    user
    status { 'presence' }
    work_mins { 480 }
    time { '23:07' }
  end
end
