# frozen_string_literal: true

# Инстанс GREEN-API, к которому подключён канал переписки с клиентами: по
# строке на канал. Реквизиты меняют из Айса, без правки окружения сервера и
# перезапуска.
#
# Токены хранятся зашифрованными ключом приложения: токен инстанса даёт полный
# доступ к аккаунту мессенджера — читать всю переписку и писать от имени
# компании. Если ключ приложения сменится, токены перестанут читаться, и
# канал будет считаться ненастроенным, пока их не введут заново.
class GreenApiInstance < ApplicationRecord
  URL_FORMAT = %r{\Ahttps?://[^\s/]+[^\s]*\z}

  belongs_to :updated_by, class_name: 'User', optional: true

  validates :channel, inclusion: { in: GreenApi::Channel::REGISTRY.keys }, uniqueness: true
  validates :api_url, :id_instance, presence: true
  validates :api_url, format: { with: URL_FORMAT }
  validates :media_url, format: { with: URL_FORMAT }, allow_blank: true
  validates :id_instance, format: { with: /\A\d+\z/ }, allow_blank: true
  validate :tokens_present

  before_validation :normalize
  before_validation :generate_webhook_token, if: -> { encrypted_webhook_token.blank? }

  def api_token
    decrypt(encrypted_api_token)
  end

  def api_token=(value)
    self.encrypted_api_token = value.presence && encryptor.encrypt_and_sign(value.to_s.strip)
  end

  # Секрет, который GREEN-API кладёт в заголовок Authorization каждого
  # уведомления. Его знают только Айс и инстанс, вводить его никому не нужно.
  def webhook_token
    decrypt(encrypted_webhook_token)
  end

  def webhook_token=(value)
    self.encrypted_webhook_token = value.presence && encryptor.encrypt_and_sign(value.to_s)
  end

  def credentials
    GreenApi::Credentials.new(api_url: api_url.to_s, media_url: media_url.to_s, instance_id: id_instance.to_s,
                              token: api_token.to_s, webhook_token: webhook_token.to_s, source: :db)
  end

  private

  def normalize
    self.api_url = api_url.to_s.strip.chomp('/')
    self.media_url = media_url.to_s.strip.chomp('/').presence
    self.id_instance = id_instance.to_s.strip
  end

  def generate_webhook_token
    self.webhook_token = SecureRandom.hex(32)
  end

  def tokens_present
    errors.add(:api_token, :blank) if encrypted_api_token.blank?
  end

  def decrypt(value)
    value.present? ? encryptor.decrypt_and_verify(value) : nil
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    nil
  end

  def encryptor
    key = Rails.application.key_generator.generate_key('green_api_instance tokens', 32)
    ActiveSupport::MessageEncryptor.new(key, cipher: 'aes-256-gcm')
  end
end
