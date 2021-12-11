require 'rails_helper'

describe PaymentType do

  it 'is valid with valid attributes' do
    payment_type = build :payment_type
    expect(payment_type).to be_valid
  end

end
