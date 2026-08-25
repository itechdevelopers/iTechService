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
