require 'rails_helper'

describe "announcements/new" do
  before(:each) do
    assign(:announcement, stub_model(Announcement,
      :content => "MyString",
      :type => "",
      :user => nil
    ).as_new_record)
  end

  it "renders new announcement form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form", :action => announcements_path, :method => "post" do
      assert_select "input#announcement_content", :name => "announcement[content]"
      assert_select "input#announcement_type", :name => "announcement[type]"
      assert_select "input#announcement_user", :name => "announcement[user]"
    end
  end
end
