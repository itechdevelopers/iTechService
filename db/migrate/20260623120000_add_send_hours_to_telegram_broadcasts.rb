class AddSendHoursToTelegramBroadcasts < ActiveRecord::Migration[5.1]
  def change
    # Индивидуальный час/окно отправки на рассылку. nil → дефолт 09:00 (как было).
    add_column :telegram_broadcasts, :send_hour_from, :integer
    add_column :telegram_broadcasts, :send_hour_to,   :integer
    # Внутрисуточный дедуп для окна «каждый час»: last_sent_on (дата) держит счёт
    # every_n_days, а last_sent_at отвечает на вопрос «в этом часу уже слали?».
    add_column :telegram_broadcasts, :last_sent_at, :datetime
  end
end
