# frozen_string_literal: true

# Одна попытка расчёта по работе. Попыток может быть несколько: после возврата
# чека расчёт начинается заново, поэтому идентификатор попытки (uid) и номер
# работы — разные ключи. uid связывает наши ретраи с одним чеком в 1С,
# ticket_number остаётся сквозным ключом поиска, в том числе для чеков,
# пробитых вручную.
class ServiceJobCheckout < ApplicationRecord
  enum state: { draft: 0, sent: 1, send_failed: 2, paid: 3, archived: 4, cancelled: 5 }

  belongs_to :service_job
  belongs_to :initiator, class_name: 'User', optional: true
  belongs_to :confirmed_by, class_name: 'User', optional: true

  scope :recent_first, -> { order(id: :desc) }
  # «Расчёт идёт»: чек создан или висит на ретраях, денег ещё нет.
  scope :in_progress, -> { where(state: [states[:sent], states[:send_failed]]) }
  # «Деньги получены» — этого достаточно, чтобы закрыть работу.
  scope :settled, -> { where(state: [states[:paid], states[:archived]]) }
  scope :awaiting_confirmation, -> { where(manual: true, confirmed_at: nil) }
  scope :needs_parts_review, -> { where(parts_review_required: true) }

  validates :uid, presence: true, uniqueness: true
  validates :expected_total, numericality: { greater_than_or_equal_to: 0 }
  validates :attempts, numericality: { greater_than_or_equal_to: 0 }

  before_validation :generate_uid

  def settled?
    paid? || archived?
  end

  def in_progress?
    sent? || send_failed?
  end

  # Пока денег нет, расчёт можно отозвать — в том числе не уехавший черновик:
  # очередь может стоять, а работу надо разблокировать.
  def cancellable?
    draft? || sent? || send_failed?
  end

  # Оплачено, но работа осталась открытой: валидации архива не пропустили.
  def stuck_after_payment?
    paid? && not_archived_reason.present?
  end

  def total_mismatch?
    paid_total.present? && paid_total != expected_total
  end

  def total_difference
    return 0 if paid_total.nil?

    paid_total - expected_total
  end

  def payment_kinds
    payments.map { |payment| payment['kind'] }.compact
  end

  private

  def generate_uid
    self.uid ||= SecureRandom.uuid
  end
end
