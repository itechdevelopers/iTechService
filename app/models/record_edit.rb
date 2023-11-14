class RecordEdit < ApplicationRecord
  belongs_to :editable, polymorphic: true
  belongs_to :user

  scope :history_for_editable, ->(params) {
    where(editable_type: params[:editable_type], editable_id: params[:editable_id])
    .where.not(updated_text: nil).order(created_at: :desc)
  }

  def self.any_edits?(record)
    edits = where(editable: record)
    edits.present? ? true : false
  end
end
