require 'rails_helper'

describe "announcements/show" do
  before(:each) do
    @announcement = assign(:announcement, stub_model(Announcement,
      :content => "Content",
      :type => "Type",
      :user => nil
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/Content/)
    rendered.should match(/Type/)
    rendered.should match(//)
  end
end
