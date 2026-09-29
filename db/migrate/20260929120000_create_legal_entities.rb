class CreateLegalEntities < ActiveRecord::Migration[5.1]
  def change
    create_table :legal_entities do |t|
      t.string :name, null: false
      t.string :ogrn_inn, null: false
      t.string :legal_address, null: false
      t.timestamps
    end

    add_reference :departments, :legal_entity, index: true
    # restrict_with_error в модели видит только активные подразделения (default_scope),
    # поэтому привязку архивных при удалении организации снимает сама база.
    add_foreign_key :departments, :legal_entities, on_delete: :nullify
  end
end
