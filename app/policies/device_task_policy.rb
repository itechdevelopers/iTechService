class DeviceTaskPolicy < BasePolicy
  def update?
    same_department? &&
      (
        any_admin? || user.role_match?(record.role) || user.code_match?(record.code) ||
          able_to?(:perform_service_center_tasks) && record.service_center? ||
          able_to?(:perform_engraving_tasks) && record.engraving?
      )
  end
end
