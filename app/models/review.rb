class Review < ApplicationRecord
  belongs_to :client, optional: true
  belongs_to :service_job, optional: true
  belongs_to :user, optional: true

  after_update :create_announcement,
    if: Proc.new { value.present? && value.to_i < 4 }

  def sent?
    status == 'sent'
  end

  def viewed!
    update! status: 'viewed'
  end

  private

    def create_announcement
      Announcement.create! kind: 'bad_review', content: id, active: true
    end
end
