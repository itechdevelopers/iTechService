require 'paperclip'

class WikiPageAttachment < ApplicationRecord
  acts_as_wiki_page_attachment do
    has_attached_file :wiki_page_attachment, styles: { large: "600x600", medium: "300x300>", thumb: "100x100>" }
    validates_attachment_presence :wiki_page_attachment, message: " is missing."
    validates_attachment_content_type :wiki_page_attachment, content_type: ['image/jpeg','image/jpg','image/png',
                                                                            'image/x-png','image/gif','image/pjpeg'],
                                      message: ' must be a JPEG, PNG or GIF.'
  end

  # attr_accessible :wiki_page_attachment, :page_id
end
