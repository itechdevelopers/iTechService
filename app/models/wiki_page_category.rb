class WikiPageCategory < ApplicationRecord
  WIKI_TAG_COLORS = %w[e0ecea 060503 b8aaaf 281f0a 5b6dd5 299c6f d2ce2a db4216].freeze
  MATCHING_COLORS = {
    "e0ecea": ["#b31c64", "#b31c64"],
    "060503": ["#11b7b9", "#11b7b9"],
    "b8aaaf": ["#09292d", "#09292d"],
    "281f0a": ["#c6e64d", "#000000"],
    "5b6dd5": ["#0ef383", "#0ef383"],
    "299c6f": ["#124100", "#124100"],
    "d2ce2a": ["#43867a", "#43867a"],
    "db4216": ["#abf7e1", "#abf7e1"],
    "ffffff": ["#000000", "#000000"]
  }.freeze

  has_many :wiki_pages, dependent: :nullify

  validates :title, presence: true
  validates :color_tag, format: {with: /\A\h{3,6}\Z/}, allow_nil: true

  scope :exclusive_senior_categories, -> {
    where.not(id:
      WikiPage.where(senior: false)
      .pluck(:wiki_page_category_id).uniq
    )
  }

  scope :exclusive_superadmin_categories, -> {
    where.not(id:
      WikiPage.where(superadmin: false)
      .pluck(:wiki_page_category_id).uniq
    )
  }

  scope :without_superadmin, -> {
    where.not(id: exclusive_superadmin_categories)
  }

  scope :without_superadmin_and_senior, -> {
    where.not(id: exclusive_senior_categories + exclusive_superadmin_categories)
  }

  def matching_font_color
    MATCHING_COLORS[color_tag.to_sym][0]
  end

  def matching_border_color
    MATCHING_COLORS[color_tag.to_sym][1]
  end
end
