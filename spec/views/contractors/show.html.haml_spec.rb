require 'rails_helper'

describe "contractors/show" do
  before(:each) do
    @contractor = assign(:contractor, stub_model(Contractor,
      :name => "Name"
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/Name/)
  end
end
