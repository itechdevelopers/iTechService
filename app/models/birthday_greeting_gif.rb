class BirthdayGreetingGif < ApplicationRecord
  belongs_to :greeting, class_name: 'BirthdayGreeting',
                        foreign_key: 'birthday_greeting_id', inverse_of: :gifs

  mount_uploader :file, BirthdayGreetingGifUploader

  validates :file, presence: true
end
