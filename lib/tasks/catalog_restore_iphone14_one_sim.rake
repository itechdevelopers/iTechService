require 'json'

namespace :catalog do
  desc 'Preview missing iPhone 14/Pro/Pro Max 1 SIM variants; APPLY=1 to restore after review'
  task restore_iphone14_one_sim: :environment do
    abort 'APPLY must be unset or 1' unless ENV['APPLY'].nil? || ENV['APPLY'] == '1'
    puts JSON.pretty_generate(Catalog::RestoreIphone14OneSim.new.call(apply: ENV['APPLY'] == '1'))
  end
end
