class AddAdminAssignableToAbilities < ActiveRecord::Migration[5.1]
  def up
    add_column :abilities, :admin_assignable, :boolean, default: false, null: false

    Ability.where(name: %w[track_elqueue_work work_with_electronic_queues])
           .update_all(admin_assignable: true)
  end

  def down
    remove_column :abilities, :admin_assignable
  end
end
