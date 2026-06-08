class Merit::Contract::Base < BaseContract
  model :merit
  properties :recipient_id, :issued_by_id, :date, :comment
  properties :recipient, :issued_by, writeable: false
  validates :recipient_id, :date, :comment, presence: true
end
