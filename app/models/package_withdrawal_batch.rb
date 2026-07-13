# frozen_string_literal: true

# Мультизабор: один сабмит формы = несколько заборов (по позиции «дизайн+размер»),
# у которых общие «Дата» и «Основание». В БД родителя нет — каждая строка это
# самостоятельный PackageWithdrawal со своим списанием и уведомлением о низком
# остатке. Этот объект-контейнер нужен только чтобы (1) собрать строки из формы,
# (2) провалидировать их разом и (3) сохранить всё-или-ничего в одной транзакции,
# а при ошибке — вернуть per-row ошибки во вьюху (как accepts_nested_attributes_for,
# только снаружи модели, потому что «родителя» нет).
class PackageWithdrawalBatch
  include ActiveModel::Model

  attr_accessor :user, :withdrawn_on, :reason

  # На пустой форме (GET new) lines= не вызывался — отдаём пустой массив, чтобы
  # вьюха могла безопасно итерировать.
  def withdrawals
    @withdrawals ||= []
  end

  validates :withdrawn_on, presence: true
  validates :reason, presence: true
  validate :at_least_one_line
  validate :lines_valid

  # lines — массив хешей/Parameters { package_stock_id:, boxes_count: } из формы.
  # Строки без количества (не отмеченные позиции) отсеиваем до постройки записей —
  # «взято» определяется наличием числа коробок, а не отдельным чекбоксом.
  def lines=(lines)
    @withdrawals = Array(lines).filter_map do |line|
      next if line[:boxes_count].to_i.zero?

      PackageWithdrawal.new(
        package_stock_id: line[:package_stock_id],
        boxes_count: line[:boxes_count]
      )
    end
  end

  def save
    return false unless valid?

    ActiveRecord::Base.transaction do
      withdrawals.each(&:save!)
    end
    true
  rescue ActiveRecord::RecordInvalid
    # Гонка: остаток мог измениться между валидацией и сохранением — откат всего.
    false
  end

  private

  def at_least_one_line
    errors.add(:base, :no_lines) if withdrawals.blank?
  end

  # Валидируем каждую строку с уже проставленными общими полями (user/дата/основание
  # приходят из контейнера — belongs_to :user требует их ещё на этапе valid?).
  # Ошибки остаются на самих записях: вьюха итерирует по withdrawals построчно.
  def lines_valid
    return if withdrawals.blank?

    invalid = false
    withdrawals.each do |withdrawal|
      assign_shared(withdrawal)
      invalid = true unless withdrawal.valid?(:create)
    end
    errors.add(:base, :invalid_line) if invalid
  end

  def assign_shared(withdrawal)
    withdrawal.user = user
    withdrawal.withdrawn_on = withdrawn_on
    withdrawal.reason = reason
  end
end
