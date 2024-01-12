class Review < ApplicationRecord
  belongs_to :client, optional: true
  belongs_to :service_job, optional: true
  belongs_to :user, optional: true

  before_update :remove_announcement,
    if: Proc.new { value.present? && value.to_i > 3 }

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
      Announcement.find_or_create_by(kind: 'bad_review', content: id) do |announcement|
        announcement.active = true
      end
    end

    def remove_announcement
      Announcement.find_by(kind: 'bad_review', content: id)&.destroy
    end
end
