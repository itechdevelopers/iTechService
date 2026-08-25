# frozen_string_literal: true

# Ревизия запчастей: заголовок, строки, подписчики-адресаты и связь с
# порождёнными складскими документами. Четыре таблицы одной миграцией —
# по отдельности они бессмысленны.
class CreateInventories < ActiveRecord::Migration[5.1]
  def change
    create_table :inventories do |t|
      t.references :store,      foreign_key: true, null: false
      # Денормализация из store.department_id: технарь видит только ревизии
      # своего филиала, и этот фильтр не должен тянуть join на каждый запрос.
      t.references :department,  foreign_key: true, null: false
      t.references :user,        foreign_key: true, null: false

      t.integer :status,    null: false, default: 0
      t.integer :sort_mode, null: false, default: 0

      # Не писать модель в названии позиции («iPhone 15 Pro Экран» → «Экран»)
      t.boolean :hide_model_in_name, null: false, default: false
      # Включать позиции, которых по учёту на складе нет
      t.boolean :include_zero_remnants, null: false, default: false

      t.text :comment

      t.datetime :sent_at
      # Момент нажатия «Начать»: именно на него снимаются остатки, поэтому
      # хранится отдельно от sent_at — между ними могут пройти дни.
      t.datetime :started_at
      t.datetime :submitted_at
      t.datetime :finished_at

      t.timestamps
    end

    add_index :inventories, :status

    create_table :inventory_lines do |t|
      t.references :inventory, foreign_key: true, null: false
      t.references :item,      foreign_key: true, null: false
      t.references :counted_by, foreign_key: { to_table: :users }

      t.integer :position, null: false

      # Остаток по учёту на момент started_at. nil до старта ревизии.
      t.integer :expected_quantity
      # Факт. nil — строка не заполнена; 0 — заполнена нулём, это результат
      # ревизии. Различие принципиально: «Ревизия готова» требует, чтобы ни
      # одной nil-строки не осталось.
      t.integer :counted_quantity
      t.datetime :counted_at

      t.boolean :recount_requested, null: false, default: false
      t.integer :resolution

      # Снимки на момент формирования списка: ревизию печатают и принимают
      # спустя недели, переименование товара или новая закупка не должны
      # задним числом менять уже проведённый документ.
      t.string  :snapshot_name
      t.decimal :snapshot_purchase_price, precision: 10, scale: 2
      t.integer :usage_count

      t.timestamps
    end

    add_index :inventory_lines, %i[inventory_id position]
    add_index :inventory_lines, %i[inventory_id item_id], unique: true

    create_table :inventory_subscriptions, id: false do |t|
      t.references :inventory,  null: false, index: { name: 'idx_inventory_subscriptions_on_inventory' }
      t.references :subscriber, null: false, index: { name: 'idx_inventory_subscriptions_on_subscriber' }
    end
    add_index :inventory_subscriptions, %i[inventory_id subscriber_id],
              unique: true, name: 'idx_inventory_subscriptions_unique'

    # Документы, порождённые приёмом расхождений (DeductionAct и др.).
    # Полиморфная связь, чтобы не добавлять inventory_id в чужие таблицы.
    create_table :inventory_documents do |t|
      t.references :inventory, foreign_key: true, null: false
      t.references :document, polymorphic: true, null: false, index: { name: 'idx_inventory_documents_on_document' }

      t.timestamps
    end
  end
end
