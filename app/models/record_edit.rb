class RecordEdit < ApplicationRecord
  belongs_to :editable, polymorphic: true
  belongs_to :user
end
