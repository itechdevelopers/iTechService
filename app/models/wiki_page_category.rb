class WikiPageCategory < ApplicationRecord
  has_many :wiki_pages

  validates :title, presence: true
end
