require 'rails_helper'

describe User do

  context 'with valid attributes' do

    it 'is valid with valid attributes' do
      user = build :user
      expect(user).to be_valid
    end

    it 'should return work_days in given period' do

    end

    it 'should return work_hours in given period' do

    end

    it 'should return sickness_days in given period' do

    end

    it 'should return latenesses in given period' do

    end

  end

  context 'with invalid attributes' do

    it "is not valid without 'username'" do
      user = build :user_without_username
      user.should_not be_valid
    end

    it "is not valid without 'password'" do
      user = build :user_without_password
      user.should_not be_valid
    end

  end

  describe 'abilities' do

    context 'superadmin' do
      subject(:superadmin) { create :user, :superadmin }

    end

    context 'admin' do

    end

    context 'manager' do

    end

    context 'software' do

    end

    context 'media' do

    end

    context 'technician' do

    end

    context 'supervisor' do

    end

    context 'programmer' do

    end

  end

end
