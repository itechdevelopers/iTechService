class CreateClientRequests < ActiveRecord::Migration[5.1]
  def up
    create_table :client_requests do |t|
      t.references :client,     foreign_key: true, null: false
      t.references :item,       foreign_key: true, null: false
      t.references :user,       foreign_key: true, null: false
      t.references :department, foreign_key: true, null: false

      t.integer :kind,                  null: false, default: 0
      t.integer :status,                null: false, default: 0
      t.text    :reason
      t.integer :purchase_check_status, null: false, default: 0
      t.date     :sold_at
      t.datetime :purchase_checked_at
      t.string   :purchase_check_error

      t.timestamps
    end

    # Ability-чекбокс в профиле сотрудника. admin_assignable: true — чтобы
    # галочка была видна и старшим менеджерам (manage_limited_rights), не только
    # под manage_rights. find_or_create_by! — идемпотентно при повторном прогоне.
    Ability.find_or_create_by!(name: 'work_with_receipt_search_requests') do |ability|
      ability.admin_assignable = true
    end
  end

  def down
    Ability.find_by(name: 'work_with_receipt_search_requests')&.destroy
    drop_table :client_requests
  end
end
