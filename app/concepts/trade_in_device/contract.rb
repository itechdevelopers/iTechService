class TradeInDevice::Contract < BaseContract
  model TradeInDevice
  properties :item, :client, :department, writeable: false

  properties :item_id, :client_id, :appraised_value, :bought_device, :client_name, :client_phone,
             :check_icloud, :appraiser, :received_at, :replacement_status, :archived,
             :archiving_comment, :condition, :equipment, :apple_guarantee, :department_id,
             :confirmed, :extended_guarantee, :sale_amount

  collection :check_list_responses, 
             populate_if_empty: CheckListResponse do
    property :id
    property :check_list_id
    property :responses
    
    validates :check_list_id, presence: true
  end

  validates :received_at, :item_id, :client_id, :appraised_value, :appraiser, :bought_device,
            :check_icloud, presence: true
end
