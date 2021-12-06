require 'rails_helper'

describe "messages/new" do
  before(:each) do
    assign(:message, stub_model(Message,
      :user => nil,
      :content => "MyString",
      :recipient => nil
    ).as_new_record)
  end

  it "renders new message form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form", :action => messages_path, :method => "post" do
      assert_select "input#message_user", :name => "message[user]"
      assert_select "input#message_content", :name => "message[content]"
      assert_select "input#message_recipient", :name => "message[recipient]"
    end
  end
end
