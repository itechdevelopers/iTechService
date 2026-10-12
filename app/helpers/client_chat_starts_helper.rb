# frozen_string_literal: true

module ClientChatStartsHelper
  # Что сказать про канал в модалке «Новый диалог»: можно ли туда написать, а
  # если нельзя — почему.
  def chat_start_option_status(option)
    scope = 'client_chat_starts.form.statuses'
    case option.status
    when :available then chat_start_available_status(option, scope)
    when :open then t("#{scope}.open")
    when :not_found
      option.checked_at ? t("#{scope}.not_found_on", date: l(option.checked_at.to_date)) : t("#{scope}.not_found")
    when :paused then t("#{scope}.paused", time: option.retry_at.in_time_zone.strftime('%H:%M'))
    when :limit_reached
      limit = ClientChat::StartConversation.daily_limit(option.channel)
      limit.zero? ? t("#{scope}.limit_zero") : t("#{scope}.limit_reached", limit: limit)
    else t("#{scope}.#{option.status}", default: t("#{scope}.error"))
    end
  end

  # Почему не отправилось. Подробная причина видна у самого канала —
  # доступность после неудачной отправки пересчитывается заново.
  def chat_start_refusal(result)
    scope = 'client_chat_starts.form'
    return t("#{scope}.choose_channel") if result.nil?
    return t("#{scope}.empty_body") if result.status == :empty_body

    t("#{scope}.refused")
  end

  private

  # Бот найден по прежнему чату — показываем, когда человек писал; мессенджер
  # по номеру — имя профиля, если мессенджер его сообщает.
  def chat_start_available_status(option, scope)
    if ClientConversation::BOT_CHANNELS.include?(option.channel)
      date = option.last_activity_at
      return date ? t("#{scope}.bot_known", date: l(date.to_date)) : t("#{scope}.bot_chat")
    end
    return t("#{scope}.available_named", name: option.name) if option.name.present?

    option.channel == 'whatsapp' ? t("#{scope}.whatsapp_unnamed") : t("#{scope}.available")
  end
end
