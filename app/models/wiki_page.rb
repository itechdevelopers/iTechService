class WikiPage < ApplicationRecord
  mount_uploaders :images, ApplicationUploader

  belongs_to :creator, class_name: 'User'
  belongs_to :updator, class_name: 'User', optional: true
  belongs_to :wiki_page_category, optional: true

  has_many :documents, class_name: 'WikiDocument', dependent: :destroy

  accepts_nested_attributes_for :documents, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :wiki_page_category, reject_if: :all_blank

  validates :content, :title, presence: true, allow_blank: false

  def self.search(params)
    results = all
    params.each do |key, value|
      field = key.sub("_filter", "")
      results = results.send("filter_by_#{field}", value) if value.present?
    end
    results
  end

  scope :filter_by_title, ->(title) { where("lower(title) like :t", t: "%#{title.downcase}%") }
  scope :filter_by_wiki_page_category, ->(wiki_page_category_id) { where(wiki_page_category_id: wiki_page_category_id) }
  scope :regular, -> { where(senior: false).where(superadmin: false) }
  scope :senior, -> { where(senior: true) }
  scope :superadmin, -> { where(superadmin: true) }
end
