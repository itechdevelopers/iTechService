require 'rails_helper'

describe "quick_tasks/new" do
  before(:each) do
    assign(:quick_task, stub_model(QuickTask,
      :name => "MyString"
    ).as_new_record)
  end

  it "renders new quick_task form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", quick_tasks_path, "post" do
      assert_select "input#quick_task_name[name=?]", "quick_task[name]"
    end
  end
end
