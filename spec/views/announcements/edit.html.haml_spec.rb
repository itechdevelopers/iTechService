require 'rails_helper'

describe "announcements/edit" do
  before(:each) do
    @announcement = assign(:announcement, stub_model(Announcement,
      :content => "MyString",
      :type => "",
      :user => nil
    ))
  end

  it "renders the edit announcement form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form", :action => announcements_path(@announcement), :method => "post" do
      assert_select "input#announcement_content", :name => "announcement[content]"
      assert_select "input#announcement_type", :name => "announcement[type]"
      assert_select "input#announcement_user", :name => "announcement[user]"
    end
  end
end
