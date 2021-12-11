require 'rails_helper'

describe "movement_acts/show" do
  before(:each) do
    @movement_act = assign(:movement_act, stub_model(MovementAct,
      :src_store_id => 1,
      :dst_store_id => 2
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/1/)
    rendered.should match(/2/)
  end
end
