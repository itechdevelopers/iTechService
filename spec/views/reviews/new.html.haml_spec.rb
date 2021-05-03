require 'rails_helper'

RSpec.describe "reviews/new", type: :view do
  before(:each) do
    assign(:review, Review.new(
      :client => nil,
      :service_job => nil,
      :value => 1,
      :content => "MyText",
      :token => "MyString"
    ))
  end

  it "renders new review form" do
    render

    assert_select "form[action=?][method=?]", reviews_path, "post" do

      assert_select "input#review_client_id[name=?]", "review[client_id]"

      assert_select "input#review_service_job_id[name=?]", "review[service_job_id]"

      assert_select "input#review_value[name=?]", "review[value]"

      assert_select "textarea#review_content[name=?]", "review[content]"

      assert_select "input#review_token[name=?]", "review[token]"
    end
  end
end
