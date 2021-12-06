require 'rails_helper'

describe "contractors/new" do
  before(:each) do
    assign(:contractor, stub_model(Contractor,
      :name => "MyString"
    ).as_new_record)
  end

  it "renders new contractor form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", contractors_path, "post" do
      assert_select "input#contractor_name[name=?]", "contractor[name]"
    end
  end
end
