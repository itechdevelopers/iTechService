# frozen_string_literal: true

module ClientChat
  # Номер собеседника из мессенджера и поиск по нему карточки клиента.
  module Phone
    # Международный формат: 11 цифр у России, 12 — у Беларуси. Если человек
    # скрыл номер настройками приватности, MAX присылает вместо него 0 — такое
    # значение номером не считаем, иначе в карточке диалога стоял бы «0».
    FORMAT = /\A\d{11,12}\z/

    # Мобильный без кода страны (9XX…) в карточках клиентов встречается, а
    # аккаунт в MAX бывает только на мобильном — такому номеру дописываем 7.
    # Десятизначные городские номера мобильными не станут, их не трогаем.
    def self.normalize(raw)
      phone = PhoneNormalizer.normalize(raw).to_s
      phone = "7#{phone}" if phone.length == 10 && phone.start_with?('9')
      phone.match?(FORMAT) ? phone : nil
    end

    # Сначала точное совпадение — оно идёт по индексу. Потом по одним цифрам:
    # номера в карточках записаны как попало (+7…, 8…, со скобками и пробелами,
    # без кода страны), и строковое сравнение их не находит. Если по цифрам
    # совпали несколько карточек, берём последнюю изменённую — скорее всего,
    # с ней и работают.
    def self.find_client(phone)
      return if phone.blank?

      Client.find_by(full_phone_number: phone) ||
        Client.where("regexp_replace(clients.full_phone_number, '[^0-9]', '', 'g') IN (?)", spellings(phone))
              .order(updated_at: :desc).first
    end

    # Как ещё мог быть записан тот же номер, если оставить в нём одни цифры.
    def self.spellings(phone)
      return [phone] unless phone.length == 11 && phone.start_with?('7')

      [phone, "8#{phone[1..]}", phone[1..]]
    end
    private_class_method :spellings
  end
end
