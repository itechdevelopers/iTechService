class BirthdayGreetingVariant < ApplicationRecord
  belongs_to :greeting, class_name: 'BirthdayGreeting',
                        foreign_key: 'birthday_greeting_id', inverse_of: :variants

  validates :body, presence: true
end
