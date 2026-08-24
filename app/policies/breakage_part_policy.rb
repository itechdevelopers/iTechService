# frozen_string_literal: true

# Headless policy: the picker is opened from both places where a breakage report
# is filed — the technician's task modal and the admin page — so it follows the
# same rule as ServiceJobPolicy#repair?.
class BreakagePartPolicy < ApplicationPolicy
  def choose?
    any_admin?(:technician)
  end

  def index?
    choose?
  end
end
