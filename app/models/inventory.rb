# frozen_string_literal: true

# Ревизия остатков склада запчастей: товаровед формирует список позиций,
# технари филиала считают факт, расхождения принимаются или уходят на пересчёт.
#
# Ревизия НЕ двигает остатки сама — принятые расхождения порождают штатные
# складские документы (DeductionAct и др.), которые проводятся своим #post.
# Иначе движение запчасти выпадет из SparePartMovementsReport, а средняя
# себестоимость из Purchase#post разъедется.
class Inventory < ApplicationRecord
  belongs_to :store
  belongs_to :department
  belongs_to :user

  has_many :lines, -> { order(:position) },
           class_name: 'InventoryLine', dependent: :destroy
  has_many :items, through: :lines

  # Дополнительно выбранные получатели уведомлений сверх технарей филиала.
  # HABTM по образцу DeviceUnlockRequest#subscribers.
  has_and_belongs_to_many :subscribers,
                          join_table: :inventory_subscriptions,
                          association_foreign_key: :subscriber_id,
                          class_name: 'User',
                          dependent: :destroy

  has_many :inventory_documents, dependent: :destroy

  # «Что считать»: выбранные группы каталога и точечные позиции.
  has_many :selections, class_name: 'InventorySelection', dependent: :destroy
  has_many :selected_groups, through: :selections, source: :selectable, source_type: 'ProductGroup'
  has_many :selected_products, through: :selections, source: :selectable, source_type: 'Product'

  audited

  # draft    — список формируется, филиал его не видит
  # sent     — отправлена на филиал: технари видят номер и дату, но не позиции
  # counting — технарь нажал «Начать», остатки зафиксированы, идёт заполнение
  # submitted — «Ревизия готова», ушла товароведу
  # recount  — часть позиций возвращена на пересчёт
  # finished — «Ревизия закончена», итоги подведены
  #
  # Цикл submitted → recount → counting → submitted повторяется сколько угодно
  # раз; finished терминален.
  enum status: {
    draft: 0,
    sent: 1,
    counting: 2,
    submitted: 3,
    recount: 4,
    finished: 5
  }

  # Порядок позиций в списке. _prefix — иначе alphabetical? столкнулось бы с
  # предикатами статуса в одном пространстве имён модели.
  enum sort_mode: {
    alphabetical: 0,
    cost_desc: 1,
    usage_desc: 2
  }, _prefix: :sorted

  # Учитывать ли модель при сортировке — вопрос только для алфавитного порядка:
  # в остальных режимах имя в сравнении не участвует.
  def ignore_model_in_sort?
    sorted_alphabetical? && self[:ignore_model_in_sort]
  end

  # Статусы, в которых ревизия уже видна филиалу.
  VISIBLE_TO_BRANCH = %w[sent counting recount submitted].freeze

  scope :recent, -> { order(created_at: :desc) }
  scope :visible_to_branch, -> { where(status: statuses.values_at(*VISIBLE_TO_BRANCH)) }
  scope :in_department, ->(department) { where(department_id: department) }

  validates :store, :department, :user, :status, :sort_mode, presence: true

  before_validation :set_department_from_store

  # Номер ревизии — её id, как у остальных складских документов проекта
  # (DeductionAct, Purchase, MovementAct нумеруются так же).
  def number
    id
  end

  def presentation
    "№#{number} от #{I18n.l(created_at.to_date)}"
  end

  def selection?
    selections.exists?
  end

  # Сплошная нумерация 1..N: номера строк печатаются в бланке и по ним технари
  # диктуют результаты, поэтому дырок после удаления оставаться не должно.
  def renumber_lines!
    transaction do
      lines.reload.each_with_index do |line, index|
        line.update_column(:position, index + 1) unless line.position == index + 1
      end
    end
  end

  # Старт подсчёта: с этого момента ревизия сравнивается не с текущим остатком,
  # а со снимком, снятым здесь. Поэтому технаря и предупреждают, что количество
  # считается «на текущий момент» — всё, что уедет со склада позже, останется
  # расхождением.
  def start!
    transaction do
      quantities = StoreItem.where(store_id: store_id, item_id: lines.select(:item_id))
                            .pluck(:item_id, :quantity).to_h

      lines.each do |line|
        # Позиции без строки StoreItem на складе — ноль, а не nil: «по учёту
        # нет ни одной» это полноценное значение для сверки.
        line.update!(expected_quantity: quantities[line.item_id].to_i)
      end

      update!(status: :counting, started_at: Time.zone.now)
    end
  end

  # Добавленная вручную позиция встаёт в конец, а не по правилам сортировки:
  # иначе номера уже розданных строк поехали бы, а бланк на руках у технарей
  # остался бы со старыми.
  def next_position
    (lines.maximum(:position) || 0) + 1
  end

  # Разворот выбора в номенклатуру: выбранная группа тянет за собой все свои
  # подгруппы (выбрали «iPhone» — считаем и «iPhone 15», и «iPhone 15 Pro»),
  # плюс точечно отмеченные продукты.
  def selected_products_scope
    group_ids = ProductGroup.where(id: selected_group_ids).flat_map(&:subtree_ids).uniq

    Product.where(product_group_id: group_ids)
           .or(Product.where(id: selected_product_ids))
  end

  # Заполненные строки — те, где факт вписан. Ноль считается заполнением,
  # поэтому проверка идёт на NULL, а не на присутствие значения.
  def counted_lines_count
    lines.where.not(counted_quantity: nil).count
  end

  def all_lines_counted?
    lines.any? && lines.where(counted_quantity: nil).none?
  end

  def discrepancy_lines
    lines.where.not(counted_quantity: nil)
         .where('counted_quantity <> expected_quantity')
  end

  private

  def set_department_from_store
    self.department_id ||= store&.department_id
  end
end
