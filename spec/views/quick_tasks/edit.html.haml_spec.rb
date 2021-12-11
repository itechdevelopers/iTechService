require 'rails_helper'

describe "quick_tasks/edit" do
  before(:each) do
    @quick_task = assign(:quick_task, stub_model(QuickTask,
      :name => "MyString"
    ))
  end

  it "renders the edit quick_task form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", quick_task_path(@quick_task), "post" do
      assert_select "input#quick_task_name[name=?]", "quick_task[name]"
    end
  end
end
