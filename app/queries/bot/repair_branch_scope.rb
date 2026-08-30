# frozen_string_literal: true

module Bot
  module RepairBranchScope
    module_function

    # The participation flag is the sole repair-bot eligibility rule. Keeping
    # this composition in one object prevents accidental use of main_branches.
    def call(department_class = Department)
      department_class.real.participating_in_repair_services
    end
  end
end
