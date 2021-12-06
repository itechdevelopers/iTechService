require 'rails_helper'

describe RepairTask do
  let(:department) { Department.create! name: 'Main', role: 0, code: 'main', city: 'city', address: 'address', contact_phone: '-', schedule: '-' }
  let(:sp_store) { Store.create! department: department, name: 'SpareParts', kind: 'spare_parts' }
  let(:repair_store) { Store.create! department: department, name: 'Repair', kind: 'repair' }
  let(:item) { create :item, :spare_part }

  it 'moves spare parts to repair store' do
    repair_task = RepairTask.new store: sp_store
    repair_part = repair_task.repair_parts.build quantity: 1
    sp_store_item = StoreItem.create! store: sp_store, item: item, quantity: 1
    repair_store_item = StoreItem.create! store: repair_store, item: item, quantity: 0
    repair_task.save
    expect(sp_store_item.quantity).to eq(0)
    expect(repair_store_item.quantity).to eq(1)
  end

end
