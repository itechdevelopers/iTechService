require 'rails_helper'

describe "sold_devices/show" do
  before(:each) do
    @sale = assign(:sale, stub_model(Sale,
      :device_type => nil,
      :imei => "Imei",
      :serial_number => "Serial Number"
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(//)
    rendered.should match(/Imei/)
    rendered.should match(/Serial Number/)
  end
end
