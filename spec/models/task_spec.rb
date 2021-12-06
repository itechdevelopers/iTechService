require 'rails_helper'

describe Task do
  
  it 'is valid with valid attributes' do
    task = create :task
    task.should be_valid
  end
  
  it "is not valid without 'name'" do
    task = build :task, name: ''
    task.should_not be_valid
  end
  
  describe "associations" do
    
    it "should have a 'devices' attribute" do
      task = create :task
      task.should respond_to :service_jobs
    end
    
    it "should have a 'location' attribute" do
      task = create :task
      task.should respond_to :location
    end
    
  end
  
end
