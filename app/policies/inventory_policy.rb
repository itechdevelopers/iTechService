# frozen_string_literal: true

# «Товаровед-запчастевед» = любой админ; отдельного права в таблице Ability не
# заводим. Технари филиала могут только открыть задание и вписать факт.
class InventoryPolicy < ApplicationPolicy
  # Список видят все — Scope ниже режет его до своего среза.
  def index?
    true
  end

  def show?
    manager? || visible_to_branch?
  end

  def new?
    manager?
  end

  def create?
    manager?
  end

  # Параметры (склад, порядок, опции) правятся только у черновика: после
  # отправки на филиал по ним уже развёрнут список и идёт подсчёт.
  def update?
    manager? && record.draft?
  end

  def edit?
    update?
  end

  def destroy?
    manager? && record.draft?
  end

  # Выбор номенклатуры правится там же, где остальные параметры — у черновика.
  def selection?
    update?
  end

  def update_selection?
    update?
  end

  def build_lines?
    update? && record.selection?
  end

  # Ручная правка строк — та же зона ответственности, что и параметры: только
  # товаровед и только пока список не ушёл на филиал.
  def manage_lines?
    update?
  end

  # Отправлять нечего, пока список не собран: технарь получил бы уведомление и
  # пустой бланк.
  def send_picker?
    manager? && record.draft? && record.lines.any?
  end

  def send_to_branch?
    send_picker?
  end

  # Начинает подсчёт филиал — те, кто физически считает. Админу тоже оставляем:
  # он может открыть ревизию за филиал, если там некому.
  #
  # Пустую ревизию начинать нечем: отправка её и не пропустит, но строки могли
  # исчезнуть вместе с удалённой номенклатурой.
  def start?
    record.sent? && record.lines.any? && (manager? || same_branch?)
  end

  # Вписывать факт может любой сотрудник филиала — заказчик просил, чтобы
  # ревизию заполняли одновременно несколькими людьми.
  def count_lines?
    (record.counting? || record.recount?) && (manager? || same_branch?)
  end

  # Содержимое списка. Технарю до нажатия «Начать» видны только номер и дата —
  # позиции открываются вместе с фиксацией остатков.
  def see_lines?
    manager? || !record.sent?
  end

  private

  def manager?
    any_admin?
  end

  # Технарь видит ревизию своего филиала и только после отправки на филиал —
  # черновик товароведа для него не существует.
  def visible_to_branch?
    record.status.in?(Inventory::VISIBLE_TO_BRANCH) && same_branch?
  end

  def same_branch?
    user.department_id == record.department_id
  end

  class Scope < Scope
    def resolve
      return scope.all if user.any_admin?

      scope.visible_to_branch.in_department(user.department_id)
    end
  end
end
