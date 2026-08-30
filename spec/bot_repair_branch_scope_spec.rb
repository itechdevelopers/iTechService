require 'spec_helper'
require_relative '../app/queries/bot/repair_branch_scope'

RSpec.describe Bot::RepairBranchScope do
  it 'composes real and participating scopes without main_branches' do
    participating = double('participating')
    real = double('real')
    departments = double('Department', real: real)
    expect(real).to receive(:participating_in_repair_services).and_return(participating)
    expect(Bot::RepairBranchScope.call(departments)).to equal(participating)
  end
end
