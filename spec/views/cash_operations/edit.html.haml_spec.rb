require 'rails_helper'

describe "cash_operations/edit" do
  before(:each) do
    @cash_operation = assign(:cash_operation, stub_model(CashOperation,
      :cash_shift => nil,
      :user => nil,
      :is_out => false,
      :value => "9.99"
    ))
  end

  it "renders the edit cash_operation form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", cash_operation_path(@cash_operation), "post" do
      assert_select "input#cash_operation_cash_shift[name=?]", "cash_operation[cash_shift]"
      assert_select "input#cash_operation_user[name=?]", "cash_operation[user]"
      assert_select "input#cash_operation_is_out[name=?]", "cash_operation[is_out]"
      assert_select "input#cash_operation_value[name=?]", "cash_operation[value]"
    end
  end
end
