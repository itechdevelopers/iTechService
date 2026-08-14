class CreateGisReviewClaims < ActiveRecord::Migration[5.1]
  def change
    # Заявка сотрудника «этот отзыв мой». Записи не удаляются: по ним видно,
    # каким образом отзыв оказался привязан к человеку.
    create_table :gis_review_claims do |t|
      t.references :gis_review, null: false, foreign_key: true
      t.references :user,       null: false, foreign_key: true

      t.integer  :status, null: false, default: 0 # pending / approved / rejected
      t.references :resolved_by, foreign_key: { to_table: :users }
      t.datetime :resolved_at
      t.text     :comment

      t.timestamps
    end

    # Одна заявка на пару «отзыв + сотрудник»: защита от повторных нажатий и от
    # повторных заявок после отказа. Ошибочное решение исправляется прямым
    # переназначением отзыва (GisReviewsController#assign).
    add_index :gis_review_claims, %i[gis_review_id user_id], unique: true
    add_index :gis_review_claims, :status
  end
end
