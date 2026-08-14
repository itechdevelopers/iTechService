# frozen_string_literal: true

class MigrateGisReviewsToPlatformContract < ActiveRecord::Migration[5.1]
  # Приводим накопленные отзывы к контракту нескольких площадок:
  #   1) проставляем площадку по префиксу идентификатора;
  #   2) срезаем префикс, схлопывая дубли, которые успел создать агент;
  #   3) проставляем подразделение по коду филиала.
  def up
    fill_sources
    strip_prefixes
    fill_departments
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'схлопнутые дубли восстановить нельзя'
  end

  private

  # Schema-миграция проставила всем '2gis'. Чужие площадки агент помечает
  # префиксом («yandex:mbDLxe...»), по нему их и опознаём.
  def fill_sources
    GisReview.where("external_review_id LIKE '%:%'").find_each do |review|
      source = GisReview.source_from_external_id(review.external_review_id)
      next if source == review.source

      review.update_columns(source: source)
      say "площадка: #{review.external_review_id} → #{source}"
    end
  end

  # Идентификатор храним БЕЗ префикса — префикс транспортная деталь, площадка
  # живёт в source. Агент переключился на префиксы раньше, чем это выкатили,
  # поэтому часть отзывов 2ГИС успела задвоиться: тот же отзыв лежит и как
  # «265062064» (до переключения), и как «2gis:265062064» (после).
  #
  # Оригиналом считаем запись БЕЗ префикса: с ней уже работали руками —
  # привязывали сотрудника, вели негатив по статусам, писали комментарии.
  def strip_prefixes
    GisReview.where("external_review_id LIKE '%:%'").find_each do |duplicate|
      prefix, stripped = duplicate.external_review_id.split(':', 2)
      next unless GisReview::SOURCES.include?(prefix)
      next if stripped.blank?

      original = GisReview.where(source: duplicate.source, external_review_id: stripped)
                          .where.not(id: duplicate.id).first

      if original.nil?
        duplicate.update_columns(external_review_id: stripped)
        say "префикс снят: #{prefix}:#{stripped} → #{stripped}"
      else
        merge_into(original, duplicate)
        say "дубль ##{duplicate.id} (#{prefix}:#{stripped}) схлопнут в ##{original.id}"
      end
    end
  end

  # Переносим на оригинал то, чего у него нет, и убираем дубль. Уведомления
  # дубля уносит dependent: :destroy в модели — иначе в колокольчике остались бы
  # ссылки на удалённый отзыв.
  def merge_into(original, duplicate)
    duplicate.comments.update_all(commentable_id: original.id)

    if original.user_id.nil? && duplicate.user_id.present?
      original.update_columns(user_id: duplicate.user_id, status: duplicate.status)
    end

    # Свежие «фактические» поля от агента: у дубля они новее по определению.
    original.update_columns(
      platform_branch_id: duplicate.platform_branch_id || original.platform_branch_id,
      text: duplicate.text.presence || original.text
    )

    duplicate.destroy
  end

  # Справочник маленький — резолвим одним запросом и раскладываем пачками.
  def fill_departments
    codes = GisReview.where(department_id: nil).distinct.pluck(:branch_code).compact
    departments = Department.where(code: codes).pluck(:code, :id).to_h

    codes.each do |code|
      department_id = departments[code]
      unless department_id
        say "branch_code #{code.inspect}: подразделение не найдено, пропускаем"
        next
      end

      updated = GisReview.where(department_id: nil, branch_code: code)
                         .update_all(department_id: department_id)
      say "branch_code #{code.inspect} → department ##{department_id}: #{updated}"
    end
  end
end
