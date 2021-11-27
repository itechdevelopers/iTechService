class TaskTemplate < ApplicationRecord
  scope :ordered, -> { order :position }

  has_ancestry
  mount_uploader :icon, IconUploader
end
