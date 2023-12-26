class TradeInApi < Grape::API
  version 'v1', using: :path

  desc 'Get list of devices available for trade in'
  get 'trade_in_devices' do
    result = []
    grouped_evaluations = TradeInDeviceEvaluation.all.group_by(&:generic_group)
    grouped_evaluations.each do |group_name, generic_group|
      items = []
      grouped_evaluations[group_name] = generic_group.group_by(&:product_group_id)
      grouped_evaluations[group_name].each do |product_group_id, evaluations|
        variants = evaluations.map { |evaluation| Entities::TradeInEntity.represent(evaluation, type: :full) }
        items << { name: ProductGroup.find(product_group_id).name, variants: variants }
      end
      result << { name: group_name, items: items }
    end

    result
  end
end