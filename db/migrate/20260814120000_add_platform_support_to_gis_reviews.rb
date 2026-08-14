class AddPlatformSupportToGisReviews < ActiveRecord::Migration[5.1]
  def up
    # ── Площадка отзыва ───────────────────────────────────────────────────────
    # Отзывы идут уже не только из 2ГИС: Яндекс приходит, vl.ru на подходе.
    # default '2gis' проставит площадку всем накопленным записям; чужие площадки
    # поправит data-миграция по префиксу идентификатора.
    add_column :gis_reviews, :source, :string, null: false, default: '2gis'

    # Уникальность идентификатора — ТОЛЬКО в пределах площадки. Раньше индекс
    # был глобальным, и отзыв Яндекса с совпавшим номером молча перезаписал бы
    # отзыв 2ГИС: upsert принял бы его за повторную отправку и вернул 200.
    remove_index :gis_reviews, column: :external_review_id
    add_index :gis_reviews, %i[source external_review_id], unique: true
    add_index :gis_reviews, :source

    # ── Идентификатор филиала на площадке ─────────────────────────────────────
    # Единое имя по согласованному контракту: id фирмы 2ГИС, businessId Яндекса,
    # id филиала vl.ru. У старых отзывов vl.ru его нет — колонка остаётся nullable.
    rename_column :gis_reviews, :branch_2gis_id, :platform_branch_id

    # ── Оценка стала необязательной ───────────────────────────────────────────
    # vl.ru разрешает оставить отзыв без звёзд, и агент не додумывает их по
    # тексту. Без этого такие отзывы получали бы 422 и терялись: очереди
    # повторов у агента нет.
    change_column_null :gis_reviews, :rating, true

    # ── Подразделение ─────────────────────────────────────────────────────────
    # Филиал по-прежнему хранится строками (агент — источник истины), но для
    # «отзывы своего подразделения» и разбивки в статистике нужна связь.
    # Резолвится по branch_code → departments.code: коды сверены на проде,
    # совпадают для всех шести филиалов и одинаковы у всех площадок.
    add_reference :gis_reviews, :department, foreign_key: true, index: true
  end

  def down
    remove_reference :gis_reviews, :department, foreign_key: true
    change_column_null :gis_reviews, :rating, false
    rename_column :gis_reviews, :platform_branch_id, :branch_2gis_id
    remove_index :gis_reviews, column: :source
    remove_index :gis_reviews, column: %i[source external_review_id]
    add_index :gis_reviews, :external_review_id, unique: true
    remove_column :gis_reviews, :source
  end
end
