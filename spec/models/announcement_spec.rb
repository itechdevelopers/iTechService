require 'rails_helper'

describe Announcement do

  context 'with valid attributes' do

    it "should have 'recipients' if 'kind' is 'device_return'" do
      users = create_list :user, 3
      announcement = create :announcement, kind: 'device_return', user: users.first, recipient_ids: users.map{ |u| u.id }
      expect(announcement.recipients.count).to be 3
    end

    it "should exclude 'recipient'" do
      users = create_list :user, 3
      user = users.first
      announcement = create :announcement, kind: 'device_return', recipient_ids: users.map { |u| u.id }
      announcement.exclude_recipient user
      expect(announcement.recipients).to_not include(user)
      expect(user).to_not be_nil
    end

    it "should change 'active' to false if no recipients left" do
      user = create :user
      announcement = create :announcement, kind: 'device_return', recipient_ids: [user.id]
      announcement.exclude_recipient user
      expect(announcement.active).to be false
    end

    it 'should be visible for recipient' do
      recipient = create :user
      announcement = create :announcement, recipient_ids: [recipient.id]
      expect(announcement.visible_for?(recipient)).to be true
    end

    it "should be visible for other softers if its kind is 'help'" do
      user1 = create :user, role: 'software'
      user2 = create :user, role: 'software'
      announcement = create :announcement, kind: 'help', user: user1, recipient_ids: [user2.id]
      expect(announcement.visible_for?(user1)).to be false
      expect(announcement.visible_for?(user2)).to be true
    end

  end

end
