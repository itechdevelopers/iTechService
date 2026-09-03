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

  # Раскрытие ветки дерева — часть той же страницы выбора.
  def selection_node?
    selection?
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

  # Сдать ревизию можно только целиком: незаполненная строка означает, что
  # позицию не считали, и товаровед принял бы её за расхождение с нулём.
  def submit?
    count_lines? && record.all_lines_counted?
  end

  # Разбор результата — работа товароведа: он видит расхождения и решает,
  # пересчитать или принять. Разница по строке и суммы в итогах восстанавливают
  # учётное количество и себестоимость, поэтому разбор закрыт тем же правом.
  def review?
    owner? && (record.submitted? || record.recount? || record.finished?)
  end

  def request_recount?
    owner? && record.submitted?
  end

  def accept_shortages?
    request_recount?
  end

  def accept_surplus?
    request_recount?
  end

  # Закрыть ревизию можно и с неразобранными расхождениями — товаровед мог
  # решить оставить их как есть. Предупреждение об этом висит на кнопке.
  def finish?
    owner? && (record.submitted? || record.recount?)
  end

  # Выгрузки доступны тем же, кому виден список: печатать пустой бланк, которого
  # ты ещё не должен видеть, смысла нет.
  def export?
    see_lines? && record.lines.any?
  end

  # Содержимое списка. Технарю до нажатия «Начать» видны только номер и дата —
  # позиции открываются вместе с фиксацией остатков.
  def see_lines?
    manager? || !record.sent?
  end

  # Себестоимость, расход и учётный остаток. Учётный остаток раскрывает ответ
  # тому, кто считает, а себестоимость — коммерческая тайна, и админ филиала,
  # где идёт ревизия, тоже её видеть не должен.
  def see_private_columns?
    owner?
  end

  private

  def manager?
    any_admin?
  end

  # Право по конкретному документу, а не по должности: ревизию товароведа не
  # должен разбирать другой товаровед.
  def owner?
    superadmin? || record.user_id == user.id
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
