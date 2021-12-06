require 'rails_helper'

describe "contractors/edit" do
  before(:each) do
    @contractor = assign(:contractor, stub_model(Contractor,
      :name => "MyString"
    ))
  end

  it "renders the edit contractor form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", contractor_path(@contractor), "post" do
      assert_select "input#contractor_name[name=?]", "contractor[name]"
    end
  end
end
