module Checkable
  extend ActiveSupport::Concern

  included do
    has_many :check_list_responses,
              as: :checkable,
              dependent: :destroy,
              inverse_of: :checkable

    accepts_nested_attributes_for :check_list_responses,
                                  allow_destroy: true,
                                  reject_if: proc { |attrs| attrs[:check_list_id].blank? }
  end

  def available_check_lists
    CheckList.active.for_entity(self.class.name)
  end

  def check_list_response_for(check_list)
    check_list_responses.find_by(check_list: check_list)
  end
end
