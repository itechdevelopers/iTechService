class CreateGisReviews < ActiveRecord::Migration[5.1]
  def change
    create_table :gis_reviews do |t|
      # Идентификатор отзыва в 2ГИС. Уникальный индекс — единственная гарантия
      # от дублей: агент пере-присылает отзывы текущего месяца на каждом прогоне.
      t.string :external_review_id, null: false

      # Город приходит строкой. Храним и её (источник истины агента), и найденную
      # связь с cities — связь может остаться пустой, если написание разошлось.
      t.string     :city_name, null: false
      t.references :city, foreign_key: true

      # Филиал агент знает сам; надёжного ключа для связи с departments нет,
      # поэтому храним как прислали.
      t.string :branch_code
      t.string :branch_name
      t.string :branch_2gis_id

      t.integer  :rating, null: false
      t.string   :author
      t.datetime :reviewed_at, null: false
      t.text     :text

      # Сотрудник, которому адресован отзыв: определил агент или привязали руками.
      t.references :user, foreign_key: true
      # Кто привязал/переназначил вручную — чтобы это было видно без раскопок в audited.
      t.references :assigned_by, foreign_key: { to_table: :users }

      # need_assignment по умолчанию: если статус почему-то не проставится,
      # отзыв попадёт в очередь ручной привязки, а не потеряется.
      t.integer :status, null: false, default: 1

      t.timestamps
    end

    add_index :gis_reviews, :external_review_id, unique: true
    add_index :gis_reviews, %i[user_id reviewed_at]
    add_index :gis_reviews, :status
  end
end
