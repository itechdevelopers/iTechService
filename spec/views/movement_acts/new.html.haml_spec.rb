require 'spec_helper'

describe "movement_acts/new" do
  before(:each) do
    assign(:movement_act, stub_model(MovementAct,
      :src_store_id => 1,
      :dst_store_id => 1
    ).as_new_record)
  end

  it "renders new movement_act form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", movement_acts_path, "post" do
      assert_select "input#movement_act_src_store_id[name=?]", "movement_act[src_store_id]"
      assert_select "input#movement_act_dst_store_id[name=?]", "movement_act[dst_store_id]"
    end
  end
end
