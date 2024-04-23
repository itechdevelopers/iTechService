class QueueItem < ApplicationRecord
  has_ancestry orphan_strategy: :rootify, cache_depth: true
  belongs_to :electronic_queue
end