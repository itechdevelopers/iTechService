require 'rails_helper'

describe "bonus_types/show" do
  before(:each) do
    @bonus_type = assign(:bonus_type, stub_model(BonusType,
      :name => "Name"
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/Name/)
  end
end
