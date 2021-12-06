require 'rails_helper'

describe "announcements/index" do
  before(:each) do
    assign(:announcements, [
      stub_model(Announcement,
        :content => "Content",
        :type => "Type",
        :user => nil
      ),
      stub_model(Announcement,
        :content => "Content",
        :type => "Type",
        :user => nil
      )
    ])
  end

  it "renders a list of announcements" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => "Content".to_s, :count => 2
    assert_select "tr>td", :text => "Type".to_s, :count => 2
    assert_select "tr>td", :text => nil.to_s, :count => 2
  end
end
