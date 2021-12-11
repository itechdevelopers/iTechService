require 'rails_helper'

describe "quick_tasks/show" do
  before(:each) do
    @quick_task = assign(:quick_task, stub_model(QuickTask,
      :name => "Name"
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/Name/)
  end
end
