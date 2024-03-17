class WikiDocument < ApplicationRecord
  belongs_to :page, class_name: 'WikiPage', foreign_key: 'wiki_page_id', inverse_of: :documents, optional: true
  mount_uploader :file, WikiDocumentUploader
end