require 'rails_helper'

describe DeviceType do
  
  it "is valid with valid attributes" do
    device_type = build :device_type
    device_type.should be_valid
  end
  
  it "is not valid without name" do
    device_type = build :invalid_device_type
    device_type.should_not be_valid
  end
  
  describe "'name' attribute" do
    it "should be unique" do
      device_type1 = create :device_type
      device_type = build :device_type
      device_type.should_not be_valid
    end
  end
  
end
