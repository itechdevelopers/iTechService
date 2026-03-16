# frozen_string_literal: true

class TelegramChat < ApplicationRecord
  validates :name, presence: true
  validates :chat_id, presence: true, uniqueness: true
end
