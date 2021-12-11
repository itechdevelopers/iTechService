require 'rails_helper'

describe Salary do

  context 'prepayments' do

    before :each do
      user = create :user
      @salary1 = create :salary, issued_at: 90.days.ago, user: user
      @prepayment1 = create :prepayment, issued_at: 80.days.ago, user: user
      @prepayment2 = create :prepayment, issued_at: 70.days.ago, user: user
      @salary2 = create :salary, issued_at: 60.days.ago, user: user
      @prepayment3 = create :prepayment, issued_at: 50.days.ago, user: user, amount: 2000
      @prepayment4 = create :prepayment, issued_at: 40.days.ago, user: user, amount: 3000
      @salary3 = create :salary, issued_at: 30.days.ago, user: user, amount: 20000
    end

    it "should return 'prepayments'" do
      expect(@salary3.prepayments.to_a).to eq([@prepayment3, @prepayment4])
    end

    it "should return 'prepayments_amount'" do
      expect(@salary3.prepayments_amount).to eq(5000)
    end

    it "should return 'full_amount'" do
      expect(@salary3.full_amount).to eq(25000)
    end

  end

end
