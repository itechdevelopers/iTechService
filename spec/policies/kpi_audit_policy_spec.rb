# frozen_string_literal: true

require_relative '../support/kpi_audit_unit_helper'
require_relative '../../app/policies/application_policy'
require_relative '../../app/policies/kpi_audit_policy'

RSpec.describe KpiAuditPolicy do
  it 'uses the existing management role boundary' do
    manager = double(role: 'manager', superadmin?: false)
    employee = double(role: 'software', superadmin?: false)

    expect(described_class.new(manager, :kpi_audit).index?).to eq(true)
    expect(described_class.new(employee, :kpi_audit).index?).to eq(false)
  end
end
