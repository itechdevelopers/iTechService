# frozen_string_literal: true

module GreenApiInstancesHelper
  STATE_LABELS = {
    'authorized' => 'label-success',
    'notAuthorized' => 'label-important',
    'blocked' => 'label-important'
  }.freeze

  # Остальные состояния (запуск, спящий режим, ограничение, ожидание пароля)
  # проходят сами или ждут действия, но канал не потерян — жёлтым.
  def green_api_state_class(state)
    STATE_LABELS.fetch(state.to_s, 'label-warning')
  end

  def green_api_webhook_class(webhook)
    { ours: 'label-success', unknown: 'label-warning' }.fetch(webhook, 'label-important')
  end
end
