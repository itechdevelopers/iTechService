json.array! @items do |item|
  json.value item.id
  json.label "#{item.name} (#{item.available_quantity} шт.)"
end
