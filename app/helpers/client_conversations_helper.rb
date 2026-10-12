# frozen_string_literal: true

module ClientConversationsHelper
  # MAX-бот и MAX по номеру — один мессенджер, значок у них общий: различает их
  # только подпись рядом, поэтому текст канала остаётся и при значке.
  CHANNEL_ICONS = {
    'telegram' => 'telegram',
    'max' => 'max',
    'max_phone' => 'max',
    'whatsapp' => 'whatsapp'
  }.freeze

  def client_channel_label(channel)
    title = t("client_conversations.conversation.channels.#{channel}", default: channel)
    icon = CHANNEL_ICONS[channel]
    return title unless icon

    content_tag(:span, class: 'client-channel') do
      image_tag("client_channels/#{icon}.svg", alt: '', class: 'client-channel__icon') + title
    end
  end
end
