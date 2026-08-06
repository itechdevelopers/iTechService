json.array! @items do |item|
  json.value item.id
  json.available item.available_quantity
  json.label "#{item.name} (#{item.available_quantity} шт.)"
end
