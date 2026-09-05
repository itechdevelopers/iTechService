# frozen_string_literal: true

# Возврат формы при увольнении. В БД родителя нет: один сабмит превращается в два
# документа — что вернули годным, уходит обратно на склад (return_from_user), что
# негодным, списывается с сотрудника (write_off_from_user). Оба сохраняются в одной
# транзакции: половина возврата хуже, чем ни одного.
#
# Невозвращённое не списываем — оно продолжает числиться за уволенным и видно
# в отчёте как долг.
class UniformReturn
  include ActiveModel::Model

  attr_accessor :employee, :author, :performed_on, :comment

  validates :employee, :author, :performed_on, presence: true
  validate :rows_within_balance

  # rows — из формы: { uniform_stock_id:, good:, unusable: } по каждой позиции,
  # которая числится за сотрудником.
  def rows=(values)
    # Поля пронумерованы в форме, поэтому с сервера приходит хеш вида {"0" => {...}},
    # а не массив — приводим к списку до разбора.
    list = values.respond_to?(:values) ? values.values : Array(values)
    @rows = list.map do |row|
      {
        uniform_stock_id: row[:uniform_stock_id].to_i,
        good: row[:good].to_i,
        unusable: row[:unusable].to_i
      }
    end
  end

  def rows
    @rows ||= []
  end

  def save
    return false unless valid?
    # Сотрудник мог не сдать ничего — это законный исход, документов просто нет.
    return true if operations.empty?

    ActiveRecord::Base.transaction { operations.each(&:save!) }
    true
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, e.record.errors.full_messages.to_sentence)
    false
  end

  def returned_count
    rows.sum { |row| row[:good] }
  end

  def written_off_count
    rows.sum { |row| row[:unusable] }
  end

  private

  def operations
    @operations ||= [build_operation('return_from_user', :good, comment),
                     build_operation('write_off_from_user', :unusable, write_off_comment)].compact
  end

  def build_operation(kind, field, text)
    lines = rows.select { |row| row[field].positive? }
                .map { |row| { uniform_stock_id: row[:uniform_stock_id], quantity: row[field] } }
    return if lines.empty?

    UniformOperation.new(kind: kind, author: author, recipient: employee, performed_on: performed_on,
                         comment: text, uniform_operation_lines_attributes: lines)
  end

  # Причина списания должна читаться и через год, когда обстоятельств никто не
  # вспомнит, поэтому её формулирует система, а не оставляет на оператора.
  def write_off_comment
    system_text = I18n.t('uniform_returns.write_off_comment', user: employee&.short_name.to_s.strip)
    [system_text, comment.presence].compact.join(' ')
  end

  def rows_within_balance
    return if employee.blank?

    balance = UniformOperationLine.holder_balance(employee)
    rows.each do |row|
      available = balance[row[:uniform_stock_id]].to_i
      next if row[:good] + row[:unusable] <= available

      stock = UniformStock.find_by(id: row[:uniform_stock_id])
      errors.add(:base, :exceeds_balance, kind: stock&.uniform_kind&.name, size: stock&.label,
                                          available: available)
    end
  end
end
