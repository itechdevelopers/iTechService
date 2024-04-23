class ElectronicQueue < ApplicationRecord
  belongs_to :department
  has_many :queue_items

  validates :department, presence: true
  validates :queue_name, presence: true
  validates :ipad_link, format: { with: /\A[a-zA-Z0-9\-_]+\z/, message: "Может содержать только латинские буквы, цифры, дефисы и символы подчеркивания." }, allow_blank: true
  validates :tv_link, format: { with: /\A[a-zA-Z0-9\-_]+\z/, message: "Может содержать только латинские буквы, цифры, дефисы и символы подчеркивания." }, allow_blank: true
end