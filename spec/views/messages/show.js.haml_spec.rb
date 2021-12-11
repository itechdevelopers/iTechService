require 'rails_helper'

describe "messages/show" do
  before(:each) do
    @message = assign(:message, stub_model(Message,
      :user => nil,
      :content => "Content",
      :recipient => nil
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(//)
    rendered.should match(/Content/)
    rendered.should match(//)
  end
end
