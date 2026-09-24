namespace :activity_counts do
  desc 'Rebuild issued repair counts from AIS history (full historical window)'
  task refresh_repairs: :environment do
    ActivityCounts::RefreshRepairs.call(full: true)
  end
end
