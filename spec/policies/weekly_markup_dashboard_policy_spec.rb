require 'rails_helper'

RSpec.describe WeeklyMarkupDashboardPolicy do
  let(:superadmin) { double(superadmin?: true) }
  let(:admin) { double(superadmin?: false) }

  %i[show branch download].each do |action|
    it "allows #{action} for superadmin only" do
      expect(described_class.new(superadmin, :weekly_markup_dashboard).public_send("#{action}?")).to eq(true)
      expect(described_class.new(admin, :weekly_markup_dashboard).public_send("#{action}?")).to eq(false)
    end
  end
end
