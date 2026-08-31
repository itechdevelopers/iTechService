# frozen_string_literal: true

require_relative '../../../app/presenters/bot/device_hierarchy_presenter'

RSpec.describe Bot::DeviceHierarchyPresenter do
  def group(id, name, ancestry: nil, archived: false)
    double(
      id: id,
      name: name,
      ancestry: ancestry,
      archived?: archived,
      respond_to?: true
    )
  end

  it 'serializes the equipment hierarchy with stable ids and parent links' do
    result = described_class.new([
      group(10, 'iPhone'),
      group(11, 'iPhone 11', ancestry: '10'),
      group(12, 'iPhone 17', ancestry: '10'),
      group(13, 'iPhone 17 Pro Max', ancestry: '10'),
      group(20, 'служебная группа', archived: true)
    ]).as_json

    root = result[:items].find { |item| item[:id] == '10' }
    expect(root[:type]).to eq('group')
    expect(root[:children].map { |item| item[:name] }).to include('iPhone 11', 'iPhone 17', 'iPhone 17 Pro Max')
    expect(root[:children].find { |item| item[:name] == 'iPhone 11' }[:parent_id]).to eq('10')
    expect(result[:items].none? { |item| item[:name] == 'служебная группа' }).to be(true)
  end

  it 'uses device type for leaf groups' do
    result = described_class.new([group(11, 'iPhone 11')]).as_json
    expect(result[:items].first[:type]).to eq('device')
  end
end
