require 'rails_helper'

describe "sold_devices/edit" do
  before(:each) do
    @sale = assign(:sale, stub_model(Sale,
      :device_type => nil,
      :imei => "MyString",
      :serial_number => "MyString"
    ))
  end

  it "renders the edit sold_device form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form", :action => sold_service_jobs_path(@sale), :method => "post" do
      assert_select "input#sold_device_device_type", :name => "sold_device[device_type]"
      assert_select "input#sold_device_imei", :name => "sold_device[imei]"
      assert_select "input#sold_device_serial_number", :name => "sold_device[serial_number]"
    end
  end
end
