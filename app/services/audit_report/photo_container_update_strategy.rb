module AuditReport
  class PhotoContainerUpdateStrategy < BaseStrategy
    ACTION_NAMES = {
      reception_photos: 'при приёмке',
      in_operation_photos: 'хода работы',
      completed_photos: 'готового устройства'
    }.freeze
    def matches?(audit)
      audit.auditable_type == 'PhotoContainer' &&
        audit.action == 'update'
    end

    def action(audit)
      changes = audit.audited_changes.select { |key, _| ACTION_NAMES.key?(key.to_sym) }
      actions = []
      changes.each do |key, change|
        prev_length = change.first&.length || 0
        new_length = change.last&.length || 0
        if new_length > prev_length
          act = 'добавил'
          qty = new_length - prev_length
        else
          act = 'удалил'
          qty = prev_length - new_length
        end
        actions << "#{act} #{qty} фото #{ACTION_NAMES[key.to_sym]}"
      end
      actions.join(' и ')
    end

    def link(audit)
      Rails.application.routes.url_helpers.service_job_path(audit.associated)
    end
  end
end
