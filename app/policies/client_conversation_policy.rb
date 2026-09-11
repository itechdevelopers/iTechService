# frozen_string_literal: true

class ClientConversationPolicy < ApplicationPolicy
  # Ящик общий: филиал диалога влияет на автоответ и фильтр, но не на то, кто
  # его видит. Отвечают Медиа, админы и обладатели права.
  def index?
    any_admin? || media_location? || able_to?(:manage_client_chats)
  end

  def show?
    index?
  end

  private

  # Location#is_media? — это code == 'content'. Роль `media` у пользователя —
  # другая сущность и доступа сюда не даёт.
  def media_location?
    user.location&.is_media?
  end
end
