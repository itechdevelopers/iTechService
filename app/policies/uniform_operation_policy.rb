# frozen_string_literal: true

# Движения формы заводят те же суперадмины, что ведут справочник видов:
# ApplicationPolicy#manage? уже равен superadmin?, и create? сводится к нему.
class UniformOperationPolicy < ApplicationPolicy
end
