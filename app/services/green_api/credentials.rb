# frozen_string_literal: true

module GreenApi
  # Реквизиты одного инстанса. Берутся заново на каждую операцию: инстанс могут
  # сменить на ходу, и процесс, запомнивший старые реквизиты, слал бы
  # сообщения с прежнего номера.
  #
  # Адресов два: обычные методы ходят на apiUrl, загрузка файлов — на mediaUrl.
  # Оба выдаются вместе с инстансом и у разных инстансов различаются, так что
  # зашить их в код нельзя.
  Credentials = Struct.new(:api_url, :media_url, :instance_id, :token, :webhook_token, :source,
                           keyword_init: true) do
    def configured?
      api_url.present? && instance_id.present? && token.present?
    end

    # Инстанс и токен — части пути, а не заголовки: так устроен весь GREEN-API.
    # Файлы GREEN-API советует грузить через mediaUrl, но принимает и через
    # apiUrl — поэтому без отдельного адреса отправка фото не ломается.
    def method_url(name, media: false)
      base = media ? media_url.presence || api_url : api_url
      "#{base}/waInstance#{instance_id}/#{name}/#{token}"
    end
  end
end
