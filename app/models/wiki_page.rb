class WikiPage < ApplicationRecord
    belongs_to :creator, class_name: 'User'
    belongs_to :updator, class_name: 'User', optional: true
    belongs_to :wiki_page_category, optional: true

    accepts_nested_attributes_for :wiki_page_category, reject_if: :all_blank

    validates :content, :creator_id, presence: true

    scope :search, ->(query) {
      if query.blank?
        all
      else
        where(
          'LOWER(wiki_pages.title) LIKE :q', q: "%#{query.downcase}%"
        )
      end
    }
end
