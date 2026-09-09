class CreateServiceJobVideos < ActiveRecord::Migration[5.1]
  def change
    create_table :service_job_videos do |t|
      t.references :service_job, null: false, foreign_key: true
      t.references :author,      foreign_key: { to_table: :users } # кто снял и прислал
      t.string     :division,    null: false # ServiceJobVideo::DIVISIONS
      t.string     :file                     # ServiceJobVideoUploader
      t.string     :poster                   # кадр-обложка, приходит из Telegram вместе с видео
      t.integer    :duration                 # секунды
      t.integer    :size                     # байты, чтобы считать занятое место в хранилище
      t.string     :telegram_file_unique_id

      t.timestamps
    end

    # Уникальность заодно служит дедупликацией: Telegram повторяет апдейт,
    # если вебхук не ответил вовремя, а file_unique_id у файла не меняется.
    add_index :service_job_videos,
              %i[service_job_id division telegram_file_unique_id],
              unique: true,
              name: 'index_service_job_videos_on_job_division_tg_file'
  end
end
