class DismissalReasonPolicy < CommonPolicy
  def manage?
    superadmin?
  end
end