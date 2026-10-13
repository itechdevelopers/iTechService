# frozen_string_literal: true

class ElqueueSoundsController < ApplicationController
  CONTENT_TYPES = { 'wav' => 'audio/wav', 'mp3' => 'audio/mpeg' }.freeze

  # ТВ склеивает фразу из записей через fetch + Web Audio, а fetch с чужого
  # домена получит байты, только если бакет отвечает CORS-заголовками. Отдаём
  # файл со своего домена, чтобы озвучка не зависела от настроек бакета.
  def audio
    sound = authorize ElqueueSound.find(params[:id])
    return unless stale?(sound)

    send_data sound.audio.read,
              type: CONTENT_TYPES.fetch(sound.audio.file.extension.to_s.downcase, 'application/octet-stream'),
              disposition: 'inline'
  end
end
