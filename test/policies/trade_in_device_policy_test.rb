require 'test_helper'

class TradeInDevicePolicyTest < ActiveSupport::TestCase
  User = Struct.new(:role, :manage_trade_in) do
    def superadmin?
      role == 'superadmin'
    end

    def able_to?(ability)
      ability.to_sym == :manage_trade_in && manage_trade_in
    end
  end

  ACTIONS = %i[manage index show create new update edit destroy print index_unconfirmed].freeze

  test 'superadmin can access trade-in devices' do
    policy = TradeInDevicePolicy.new(User.new('superadmin', false), TradeInDevice)

    ACTIONS.each { |action| assert policy.public_send("#{action}?") }
  end

  test 'non-superadmin cannot access trade-in devices even with manage_trade_in ability' do
    policy = TradeInDevicePolicy.new(User.new('admin', true), TradeInDevice)

    ACTIONS.each { |action| refute policy.public_send("#{action}?") }
  end
end
