class WikiPageCategory < ApplicationRecord
  has_many :wiki_pages, dependent: :nullify

  validates :title, presence: true
  
  scope :only_non_senior, -> {
    joins(:wiki_pages)
      .where(wiki_pages: { senior: false })
      .group('wiki_page_categories.id')
      .having('COUNT(wiki_pages.id) = ?', WikiPage.senior.count)
  }
end
