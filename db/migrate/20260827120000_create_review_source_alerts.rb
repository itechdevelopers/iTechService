class CreateReviewSourceAlerts < ActiveRecord::Migration[5.1]
  def change
    create_table :review_source_alerts do |t|
      # Площадка — та же константа, что у отзывов (2gis / yandex / vl_ru).
      t.string :source, null: false

      # Код филиала агента. Пустая строка — авария площадки целиком: у 2ГИС
      # ложится сразу весь API отзывов, и шесть одинаковых филиальных аварий
      # вместо одной глобальной только мешают разбору. Пустая строка, а не NULL,
      # потому что в уникальном индексе два NULL друг с другом не конфликтуют —
      # глобальные аварии по одной площадке спокойно задвоились бы.
      t.string :branch_code, null: false, default: ''

      # Название филиала и город агент шлёт не всегда; основной источник —
      # справочник подразделений по branch_code, эти поля нужны как фолбэк,
      # если код не резолвится.
      t.string     :branch_name
      t.string     :city_name
      t.references :department, foreign_key: true

      # Идентификатор аварии на стороне агента. Хранится для сверки с его
      # логами; уникальность на нём НЕ строим — ключ стабилен во времени
      # (2gis:vl:source_unavailable), и авария через месяц придёт с тем же
      # значением. «Тем же самым» считаем только то, что открыто сейчас.
      t.string :external_alert_id
      t.string :alert_type, null: false

      t.datetime :first_failed_at
      t.datetime :last_failed_at
      t.integer  :consecutive_failures
      # Длительность по расчёту агента. На экране считаем свою (от
      # first_failed_at до «сейчас»): агентская застынет, если он перестанет
      # слать, и доска будет уверенно показывать «24 часа» третьи сутки.
      t.float    :hours_failed

      t.text :message
      t.text :last_error

      # Пока пусто — авария открыта. Заполняется приходом source_recovered.
      t.datetime :resolved_at
      t.text     :resolved_message

      t.timestamps
    end

    # Главное правило приёма: одновременно открытой авария по паре
    # «площадка + филиал» может быть только одна, но повториться она может
    # сколько угодно раз. Частичный индекс кодирует ровно это.
    add_index :review_source_alerts, %i[source branch_code],
              unique: true,
              where: 'resolved_at IS NULL',
              name: 'index_review_source_alerts_on_open_source_and_branch'

    add_index :review_source_alerts, %i[source resolved_at]
  end
end
