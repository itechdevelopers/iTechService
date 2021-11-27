class ClientCategory < ApplicationRecord
  # attr_accessible :color, :name
  validates_presence_of :name
  default_scope {order('id asc')}

  after_initialize do
    self.color ||= '#ffffff'
  end

end
