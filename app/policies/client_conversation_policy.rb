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

  # Ответить может любой, у кого есть доступ, даже не взяв диалог в работу:
  # назначение нужно, чтобы двое не отвечали разом, а не чтобы запрещать.
  # Автор всё равно фиксируется на каждом сообщении.
  def reply?
    index?
  end

  private

  # Location#is_media? — это code == 'content'. Роль `media` у пользователя —
  # другая сущность и доступа сюда не даёт.
  def media_location?
    user.location&.is_media?
  end
end
