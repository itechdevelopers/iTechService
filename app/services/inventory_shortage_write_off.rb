# frozen_string_literal: true

# Списывает принятые недостачи ревизии одним актом списания.
#
#   result = InventoryShortageWriteOff.call(inventory, lines)
#   result.success? # => true/false
#   result.act      # => DeductionAct
#
# Ревизия не трогает остатки напрямую: она порождает штатный DeductionAct и
# проводит его. Иначе движение запчасти выпадет из отчёта по запчастям, а
# средняя себестоимость перестанет сходиться.
class InventoryShortageWriteOff
  Result = Struct.new(:act, :errors) do
    def success?
      errors.empty?
    end
  end

  def self.call(inventory, lines)
    new(inventory, lines).call
  end

  def initialize(inventory, lines)
    @inventory = inventory
    @lines = lines
  end

  def call
    return Result.new(nil, [I18n.t('inventories.accept_shortages.nothing_to_write_off')]) if shortages.empty?

    act = build_act

    return Result.new(act, act.errors.full_messages) unless act.save

    # #post сам проверяет достаточность остатка и на нехватке возвращает false,
    # накопив ошибки: остаток мог уехать уже после старта ревизии. Непроведённый
    # акт удаляем — иначе в списке актов копятся черновики от неудачных попыток,
    # и товаровед не отличит их от настоящих.
    unless act.post
      errors = act.errors.full_messages.presence || [I18n.t('inventories.accept_shortages.post_failed')]
      act.destroy
      return Result.new(nil, errors)
    end

    mark_accepted(act)
    Result.new(act, [])
  end

  private

  attr_reader :inventory, :lines

  # Принимаем только недостачи: излишек нельзя списать, для него нужна отгрузка.
  # Уже разобранные строки пропускаем — их остаток приведён к факту, и повторное
  # списание вычло бы ту же разницу второй раз.
  def shortages
    @shortages ||= lines.select { |line| line.difference.to_i.negative? && !line.resolution_accepted? }
  end

  def build_act
    act = DeductionAct.new(
      store: inventory.store,
      status: 0,
      date: Time.zone.now,
      comment: I18n.t('inventories.accept_shortages.act_comment',
                      number: inventory.number,
                      date: I18n.l(inventory.created_at.to_date))
    )

    shortages.each do |line|
      act.deduction_items.build(item_id: line.item_id, quantity: line.difference.abs)
    end

    act
  end

  def mark_accepted(act)
    Inventory.transaction do
      shortages.each { |line| line.update!(resolution: :accepted) }
      inventory.inventory_documents.create!(document: act)
    end
  end
end
