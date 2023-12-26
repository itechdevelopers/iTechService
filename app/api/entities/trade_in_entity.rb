class Entities::TradeInEntity < Grape::Entity
  expose :id
  expose :max_value, as: :max_price
  expose :option_values, if: { type: :full } do |trade_in, options|
    trade_in.option_values.map do |option_value_id|
      option_value = OptionValue.find(option_value_id)
      { option_value.option_type.name => option_value.name }
    end.reduce({}, :merge)
  end
end