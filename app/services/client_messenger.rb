# frozen_string_literal: true

# Куда уходит ответ сотрудника — решает канал диалога. Реестр вынесен из джобы,
# потому что список исключений для retry_on собирается в теле класса, на этапе
# загрузки: джоба обязана знать про транзиентные ошибки всех каналов сразу, ещё
# не видя конкретного сообщения.
#
# Адаптеры перечислены строками, а не константами, намеренно. Константа
# Telegram внутри этого модуля разрешилась бы в модуль гема telegram-bot —
# тихо, без ошибки, просто подставив не тот класс.
module ClientMessenger
  ADAPTERS = {
    'telegram' => 'ClientMessenger::TelegramAdapter'
  }.freeze

  class UnknownChannel < StandardError; end

  def self.for(conversation)
    adapter = ADAPTERS[conversation.channel]
    raise UnknownChannel, "нет адаптера для канала #{conversation.channel.inspect}" if adapter.nil?

    adapter.constantize.new
  end

  # Объединение по всем каналам — только для декларации retry_on. Вопрос
  # «повторять ли этот конкретный отказ» задаётся адаптеру, который его вернул:
  # чужие таймауты для него ничего не значат.
  def self.transient_errors
    ADAPTERS.values.flat_map { |adapter| adapter.constantize::TRANSIENT_ERRORS }.uniq
  end
end
