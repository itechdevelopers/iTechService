require 'rails_helper'

describe "sold_devices/index" do
  before(:each) do
    assign(:sales, [
      stub_model(Sale,
        :device_type => nil,
        :imei => "Imei",
        :serial_number => "Serial Number"
      ),
      stub_model(Sale,
        :device_type => nil,
        :imei => "Imei",
        :serial_number => "Serial Number"
      )
    ])
  end

  it "renders a list of sold_devices" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => nil.to_s, :count => 2
    assert_select "tr>td", :text => "Imei".to_s, :count => 2
    assert_select "tr>td", :text => "Serial Number".to_s, :count => 2
  end
end
