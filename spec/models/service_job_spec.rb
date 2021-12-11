require 'rails_helper'

describe ServiceJob do
  
  it 'is valid with valid attributes' do
    device = create :device
    expect(device).to be_valid
  end
  
  it "is not valid without 'device type'" do
    device = build :device, device_type: nil
    device.should_not be_valid
  end
  
  it "is not valid without a 'client'" do
    device = build :device, client: nil
    device.should_not be_valid
  end
  
  it "is not valid without 'ticket number'" do
    device = build :device, ticket_number: nil
    device.should_not be_valid
  end
  
  it "should have unique 'ticket number'" do
    device1 = create :device
    device = build :device_2, ticket_number: device1.ticket_number
    device.should_not be_valid
  end

  it 'should convert service_duration to return_at' do
    time = DateTime.current.change sec: 0
    device = create :device, service_duration: '5.30'
    expect(device.return_at).to eq time.advance(hours: 5, minutes: 30)
  end

  it 'should require service_duration' do
    device = build :device, :with_tasks, service_duration: nil
    device.should_not be_valid
  end

  context "associations" do
    
    before :each do
      @device = create :device
    end
    
    it "should have a 'client' attribute" do
      @device.should respond_to :client
    end
    
    it "should have a 'device_type' attributes" do
      @device.should respond_to :device_type
    end
    
    it "should have a 'client_name' attribute" do
      @device.should respond_to :client_name
    end
    
    it "should have a 'client_phone' attribute" do
      @device.should respond_to :client_phone
    end
    
    it "should have a 'type_name' attribute" do
      @device.should respond_to :type_name
    end
    
    it "should have a 'tasks' attribute" do
      @device.should respond_to :tasks
    end

    it 'should have device_tasks' do
      @device.device_tasks.create attributes_for(:device_task)
      expect(@device.device_tasks.count).to be > 0
    end
    
    it "should not create a new 'Device Type' if it is exists" do
      device_type = @device.device_type
      expect {
        device = build :device, device_type: nil
        device.build_device_type name: device_type.name
        device.save
      }.to_not change(DeviceType, :count)
    end
    
    describe "attribute 'client_name'" do
      
      it "should be equal to 'client_type.name'" do
        @device.client_name.should eq @device.client.name
      end
      
    end
    
    describe "attribute 'type_name'" do
      
      it "should be equal to 'device_type.name'" do
        @device.type_name.should eq @device.device_type.name
      end
      
    end
    
    describe "ordering" do
      
      it 'should place pending devices higher than done devices' do
        pending
      end
      
      it 'should place important pending devices on top' do
        pending
      end
      
    end
    
  end

  # should create 'delayed_job' with 'run_at' 30 mins before 'return_at' after create if 'service_duration' is greater than 30 minutes and less than 5 hours
  it "should create 'delayed_job' for short service duration" do
    now = DateTime.current.change sec: 0
    device = create :device, service_duration: '3.40'
    expect(Delayed::Job.count).to be 1
    expect(Delayed::Job.last.run_at).to eq now.advance(hours: 3, minutes: 10)
  end

  # should create delayed_job' with 'run_at' 1 hour before 'return_at' after create if 'service_duration' is 5 to 24 hours
  it "should create 'delayed_job' for medium service duration" do
    now = DateTime.current.change sec: 0
    device = create :device, service_duration: '12.0'
    expect(Delayed::Job.count).to be 1
    expect(Delayed::Job.last.run_at).to eq now.advance(hours: 11)
  end

  # should create additional 'delayed_job' with 'run_at' 1 day before 'return_at' after create if 'service_duration' is greater than 1 day
  it "should create two 'delayed_job' for long service duration" do
    now = DateTime.current.change sec: 0
    device = create :device, service_duration: '2.2.30'
    expect(Delayed::Job.count).to be 2
    expect(Delayed::Job.first.run_at).to eq now.advance(days: 2, hours: 1, minutes: 30)
    expect(Delayed::Job.last.run_at).to eq now.advance(days: 1, hours: 2, minutes: 30)
  end

  context 'announcements' do
    let!(:user_software) { create :user, :software }
    let!(:user_technician) { create :user, :technician }

    it 'creates returning announcement' do
      device = create :device, :at_bar
      device.returning_alert
      announcement = Announcement.find_by_kind_and_content('device_return', device.id.to_s)
      expect(announcement).to be
      expect(announcement.recipient_ids).to include(user_software.id)
      expect(announcement.recipient_ids).not_to include(user_technician.id)
    end

    it 'creates returning announcement with technicians in recipients if location is repair' do
      device = create :device, :at_repair
      device.returning_alert
      announcement = Announcement.find_by_kind_and_content('device_return', device.id.to_s)
      expect(announcement.recipient_ids).to include(user_technician.id)
    end

  end

end
