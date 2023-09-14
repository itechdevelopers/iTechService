class WikiPage < ApplicationRecord

  acts_as_wiki_page

  belongs_to :wiki_page_category

  scope :is_private, -> { where(private: true) }
  scope :is_common, -> { where(private: false) }

  scope :by_category, ->(category_id) { where(wiki_page_category_id: category_id) }
end
