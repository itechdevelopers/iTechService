class OperationTransaction
  extend Uber::Callable

  def self.call(*)
    ApplicationRecord.transaction { yield }
  end
end