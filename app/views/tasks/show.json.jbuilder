json.extract! @task, :id, :product_id, :cost, :is_repair?, :location_code
json.location_id @location&.id
json.location_name @location&.name