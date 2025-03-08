class ReportPermission < ApplicationRecord
  belongs_to :user
  belongs_to :report_card
  
  validates :user_id, uniqueness: { scope: :report_card_id }
end

