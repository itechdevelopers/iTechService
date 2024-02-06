class Token < ApplicationRecord
  belongs_to :user
  belongs_to :signable, polymorphic: true

  before_create :generate_token_and_expiration

  private

  def generate_token_and_expiration
    self.token = SecureRandom.hex(20)
    self.expires_at = 1.day.from_now
  end
end
