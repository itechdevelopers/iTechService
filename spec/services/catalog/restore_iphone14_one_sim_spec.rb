require 'rails_helper'

RSpec.describe Catalog::RestoreIphone14OneSim do
  let(:service) { described_class.new }

  before do
    allow(SyncProductRepairServicesJob).to receive(:perform_later)
    @repair_group = RepairGroup.create!(name: 'Phone repairs')
    @repair = RepairService.create!(name: 'Diagnosis', repair_group: @repair_group)
    category = ProductCategory.create!(name: 'Phones', kind: 'equipment', warranty_term: 12)
    category.feature_types = [FeatureType.create!(name: 'IMEI', kind: 'imei'),
                              FeatureType.create!(name: 'Serial', kind: 'serial_number')]
    @sim_type = OptionType.create!(name: 'Количество SIM')
    @one = OptionValue.create!(name: '1 SIM', code: 'one', option_type: @sim_type)
    @two = OptionValue.create!(name: '2 SIM', code: 'two', option_type: @sim_type)
    @esim = OptionValue.create!(name: 'esim', code: 'esim', option_type: @sim_type)
    @color = OptionValue.create!(name: 'Blue', code: 'blue', option_type: OptionType.create!(name: 'Цвет'))
    @capacity_type = OptionType.create!(name: 'Ёмкость')
    @memory = OptionValue.create!(name: '128GB', code: '128gb', option_type: @capacity_type)
    @groups = described_class::GROUP_NAMES.map do |name|
      group = ProductGroup.create!(name: name, product_category: category, repair_group: @repair_group)
      group.option_values = [@color, @memory, @esim]
      group
    end
    @originals = @groups.flat_map.with_index do |group, index|
      [nil, @esim, @two].map do |sim|
        Product.create!(name: "#{group.name} 128GB Blue #{sim&.name}",
                        code: "source-#{index}-#{sim&.id}", product_group: group,
                        article: "article-#{index}-#{sim&.id}",
                        option_ids: [@color.id, @memory.id, sim&.id].compact)
      end
    end
  end

  def original_snapshot
    @originals.map { |p| p.reload.attributes.merge('option_ids' => p.option_ids.sort) }
  end

  it 'previews without writing products, options or group links' do
    before = [Product.count, OptionValue.count, @groups.map { |g| g.reload.option_value_ids.sort }, original_snapshot]
    report = service.call
    expect(report[:groups].sum { |g| g[:create].size }).to eq(3)
    expect(report[:groups].all? { |g| g[:add_group_option] }).to eq(true)
    expect([Product.count, OptionValue.count, @groups.map { |g| g.reload.option_value_ids.sort }, original_snapshot]).to eq(before)
  end

  it 'restores selectable products once and preserves originals, eSIM and 2 SIM' do
    before = original_snapshot
    report = service.call(apply: true)
    created = report[:groups].flat_map { |g| g[:create] }.map { |row| Product.find(row[:id]) }
    expect(created.size).to eq(3)
    created.each do |product|
      expect(product.code).to match(/\A\d{8}\z/)
      expect(product.article).to be_nil
      expect(product.barcode_num).to match(/\A\d{13}\z/)
      expect(product.warranty_term).to eq(12)
      expect(product.feature_types.pluck(:kind).sort).to eq(%w[imei serial_number])
      expect(product.repair_service_ids).to eq([@repair.id])
      expect(Product.find_by_group_and_options(product.product_group_id, product.option_ids)).to eq(product)
    end
    expect(@groups.all? { |g| g.reload.option_value_ids.include?(@one.id) && g.option_value_ids.include?(@esim.id) }).to eq(true)
    expect(original_snapshot).to eq(before)
    expect { service.call(apply: true) }.not_to change(Product, :count)
    expect(service.call[:groups].flat_map { |g| g[:create] }).to be_empty
  end

  it 'reuses an explicit 1 SIM product even when its group option is missing' do
    existing = Product.create!(name: 'Existing', code: 'existing', product_group: @groups.first,
                              option_ids: [@color.id, @memory.id, @one.id])
    before = existing.attributes
    report = service.call(apply: true)
    expect(report[:groups].first[:reuse]).to eq([existing.id])
    expect(existing.reload.attributes).to eq(before)
  end

  it 'does not infer unknown capacity or modify spare-part groups with the same name' do
    unknown = OptionValue.create!(name: '?', code: '?', option_type: @capacity_type)
    @groups.first.option_values << unknown
    Product.create!(name: 'Unknown capacity', code: 'unknown', product_group: @groups.first,
                    option_ids: [@color.id, unknown.id])
    parts = ProductGroup.create!(name: 'iPhone 14', repair_group: @repair_group,
                                 product_category: ProductCategory.create!(name: 'Parts', kind: 'spare_part'))
    report = service.call(apply: true)
    expect(report[:groups].flat_map { |g| g[:create] }.size).to eq(3)
    expect(parts.reload.option_value_ids).to be_empty
  end

  it 'rolls back all groups when an archived explicit combination would be duplicated' do
    Product.create!(name: 'Archived', code: 'archived', product_group: @groups.last, archived: true,
                    option_ids: [@color.id, @memory.id, @one.id])
    before = Product.count
    expect { service.call(apply: true) }.to raise_error(described_class::Conflict, /archived/)
    expect(Product.count).to eq(before)
    expect(@groups.any? { |g| g.reload.option_value_ids.include?(@one.id) }).to eq(false)
  end

  it 'fails safely on duplicate explicit combinations' do
    2.times do |i|
      Product.create!(name: 'Duplicate', code: "duplicate-#{i}", product_group: @groups.first,
                      option_ids: [@color.id, @memory.id, @one.id])
    end
    expect { service.call }.to raise_error(described_class::Conflict, /Duplicate/)
  end
end
