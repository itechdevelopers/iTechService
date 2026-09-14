# frozen_string_literal: true

class SeedManageClientChatsAbility < ActiveRecord::Migration[5.1]
  # Право «Диалоги с клиентами». Диалоги ведёт локация Медиа, но отвечать
  # иногда нужно и тем, кто в ней не сидит, — им выдаётся это право вместо
  # роли админа. admin_assignable: false — выдаёт только суперадмин.
  def up
    Ability.find_or_create_by!(name: 'manage_client_chats') do |ability|
      ability.admin_assignable = false
    end
  end

  def down
    Ability.find_by(name: 'manage_client_chats')&.destroy
  end
end
