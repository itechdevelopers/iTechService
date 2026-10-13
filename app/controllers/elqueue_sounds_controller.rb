# frozen_string_literal: true

class ElqueueSoundsController < ApplicationController
  CONTENT_TYPES = { 'wav' => 'audio/wav', 'mp3' => 'audio/mpeg' }.freeze

  def index
    authorize ElqueueSound
    @phrases = ElqueueSound.phrases
  end

  # Одна форма на строку и для первой загрузки, и для замены: строка знает только
  # вид и значение фразы, а есть ли уже запись — решается здесь.
  def create
    sound = authorize ElqueueSound.find_or_initialize_by(kind: params[:kind], value: params[:value].to_s.strip)

    # Без файла у уже загруженной фразы save прошёл бы без изменений и отчитался
    # бы об успешной загрузке.
    if params[:audio].blank?
      redirect_to elqueue_sounds_path, flash: { error: t('.no_file', phrase: sound.phrase) }
      return
    end

    sound.audio = params[:audio]
    if sound.save
      flash[:notice] = t('.uploaded', phrase: sound.phrase)
    else
      # Сообщения CarrierWave уже начинаются со слова «файл», с подписью поля
      # получилось бы «Файл размер файла должен быть меньше 2 МБ».
      error = sound.errors[:audio].first || sound.errors.full_messages.first
      flash[:error] = t('.failed', phrase: sound.phrase, error: error)
    end
    redirect_to elqueue_sounds_path
  end

  def destroy
    sound = authorize ElqueueSound.find(params[:id])
    sound.destroy!
    flash[:notice] = t('.deleted', phrase: sound.phrase)
    redirect_to elqueue_sounds_path
  end

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
