require 'rails_helper'

describe "stolen_phones/show" do
  before(:each) do
    @stolen_phone = assign(:stolen_phone, stub_model(StolenPhone,
      :emei => "Emei"
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/Emei/)
  end
end
