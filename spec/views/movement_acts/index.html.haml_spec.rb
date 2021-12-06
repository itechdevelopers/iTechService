require 'rails_helper'

describe "movement_acts/index" do
  before(:each) do
    assign(:movement_acts, [
      stub_model(MovementAct,
        :src_store_id => 1,
        :dst_store_id => 2
      ),
      stub_model(MovementAct,
        :src_store_id => 1,
        :dst_store_id => 2
      )
    ])
  end

  it "renders a list of movement_acts" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => 1.to_s, :count => 2
    assert_select "tr>td", :text => 2.to_s, :count => 2
  end
end
