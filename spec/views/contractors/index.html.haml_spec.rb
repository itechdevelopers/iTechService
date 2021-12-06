require 'rails_helper'

describe "contractors/index" do
  before(:each) do
    assign(:contractors, [
      stub_model(Contractor,
        :name => "Name"
      ),
      stub_model(Contractor,
        :name => "Name"
      )
    ])
  end

  it "renders a list of contractors" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => "Name".to_s, :count => 2
  end
end
