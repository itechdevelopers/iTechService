require 'rails_helper'

describe "quick_tasks/index" do
  before(:each) do
    assign(:quick_tasks, [
      stub_model(QuickTask,
        :name => "Name"
      ),
      stub_model(QuickTask,
        :name => "Name"
      )
    ])
  end

  it "renders a list of quick_tasks" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => "Name".to_s, :count => 2
  end
end
