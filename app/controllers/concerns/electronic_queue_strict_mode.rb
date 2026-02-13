module ElectronicQueueStrictMode
  extend ActiveSupport::Concern

  private

  def enforce_electronic_queue_strict_mode
    queue = current_user.department.electronic_queues.enabled.first
    return unless queue&.strict_mode?
    return if current_user.serving_client?

    redirect_back fallback_location: root_path,
                  alert: 'У вас нет активного рабочего талона, чтобы продолжить. Выберите окно и примите талон для продолжения.'
  end
end
