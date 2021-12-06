require 'rails_helper'

describe "stolen_phones/index" do
  before(:each) do
    assign(:stolen_phones, [
      stub_model(StolenPhone,
        :emei => "Emei"
      ),
      stub_model(StolenPhone,
        :emei => "Emei"
      )
    ])
  end

  it "renders a list of stolen_phones" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => "Emei".to_s, :count => 2
  end
end
