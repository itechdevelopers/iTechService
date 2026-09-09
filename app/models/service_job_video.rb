# frozen_string_literal: true

# A short clip an employee filmed and sent to the bot, pinned to a service job
# and to the same divisions photos use.
#
# Its own table rather than more array columns on PhotoContainer: the file is
# fetched and stored by a background job, so every clip has a lifecycle of its
# own, and touching one must not lock the whole container the way
# PhotoContainer#add_photos has to.
class ServiceJobVideo < ApplicationRecord
  # Breakage reports keep photos only for now, so their division is absent here.
  DIVISIONS = %w[reception in_operation completed].freeze
  # Without the word "фото" the bot's own division labels carry: the same
  # division now holds both kinds of file.
  DIVISION_LABELS = {
    'reception' => 'При приёмке',
    'in_operation' => 'В процессе ремонта',
    'completed' => 'Готовое устройство'
  }.freeze
  PER_DIVISION_LIMIT = 3
  MAX_DURATION = 60
  # Bot API refuses to hand over anything bigger through getFile, so a clip
  # above this size is unreachable for us no matter what we do with it.
  MAX_FILE_SIZE = 20.megabytes

  mount_uploader :file, ServiceJobVideoUploader
  mount_uploader :poster, ServiceJobVideoPosterUploader

  belongs_to :service_job
  belongs_to :author, class_name: 'User', optional: true

  validates :division, inclusion: { in: DIVISIONS }

  scope :in_division, ->(division) { where(division: division) }
  scope :oldest_first, -> { order(:created_at) }

  # Without the Auditable concern on purpose: it enriches the audit from
  # User.current, which is nil in the Sidekiq worker that creates these.
  audited associated_with: :service_job

  def self.division_label(division)
    DIVISION_LABELS.fetch(division, division)
  end

  def self.division_full?(service_job_id, division)
    in_division(division).where(service_job_id: service_job_id).count >= PER_DIVISION_LIMIT
  end
end
