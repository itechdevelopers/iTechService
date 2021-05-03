require 'rails_helper'

RSpec.describe "reviews/index", type: :view do
  before(:each) do
    assign(:reviews, [
      Review.create!(
        :client => nil,
        :service_job => nil,
        :value => 2,
        :content => "MyText",
        :token => "Token"
      ),
      Review.create!(
        :client => nil,
        :service_job => nil,
        :value => 2,
        :content => "MyText",
        :token => "Token"
      )
    ])
  end

  it "renders a list of reviews" do
    render
    assert_select "tr>td", :text => nil.to_s, :count => 2
    assert_select "tr>td", :text => nil.to_s, :count => 2
    assert_select "tr>td", :text => 2.to_s, :count => 2
    assert_select "tr>td", :text => "MyText".to_s, :count => 2
    assert_select "tr>td", :text => "Token".to_s, :count => 2
  end
end
