require 'rails_helper'

describe "infos/index" do
  before(:each) do
    assign(:infos, [
      stub_model(Info,
        :title => "Title",
        :content => "MyText"
      ),
      stub_model(Info,
        :title => "Title",
        :content => "MyText"
      )
    ])
  end

  it "renders a list of infos" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => "Title".to_s, :count => 2
    assert_select "tr>td", :text => "MyText".to_s, :count => 2
  end
end
