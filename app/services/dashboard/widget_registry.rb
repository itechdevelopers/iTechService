# frozen_string_literal: true

# Реестр «дашбордов сотрудника» — крупных блоков над таблицей задач на главной.
#
# Слот определяется позицией ключа в массиве, который возвращает .for_user.
# Сейчас набор жёстко задан кодом локации, в дальнейшем сотрудник сможет
# переопределить его в профиле — поэтому единственное место, куда добавляется
# новый блок, это WIDGETS, а вёрстка дашборда о конкретных блоках не знает.
#
# partial: nil означает, что тело блока наполняется на клиенте (сейчас — из
# ответа /service/actual_feedbacks.js); серверные блоки укажут здесь партиал.
module Dashboard
  module WidgetRegistry
    WIDGETS = {
      'order_feedbacks' => { title: 'Заказы', partial: nil },
      'approvals' => { title: 'Согласование', partial: 'dashboard/widgets/approvals' },
      'service_feedbacks' => { title: 'Сервис', partial: nil }
    }.freeze

    DEFAULTS_BY_LOCATION_CODE = {
      'content' => %w[order_feedbacks approvals service_feedbacks]
    }.freeze

    # Пустой массив = блоков нет, партиал не рендерится вовсе.
    def self.for_user(user)
      return [] if user.blank?

      DEFAULTS_BY_LOCATION_CODE.fetch(user.location&.code, [])
    end

    def self.title(key)
      WIDGETS.dig(key, :title).to_s
    end

    def self.partial(key)
      WIDGETS.dig(key, :partial)
    end

    def self.dom_id(key)
      "dashboard_widget--#{key}"
    end
  end
end
