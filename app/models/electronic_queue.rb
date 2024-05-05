class ElectronicQueue < ApplicationRecord
  belongs_to :department
  has_many :queue_items
  has_many :elqueue_windows, dependent: :destroy

  validates :department, presence: true
  validates :queue_name, presence: true
  validates :ipad_link,
            format: { with: /\A[a-zA-Z0-9\-_]+\z/, message: "Может содержать только латинские буквы, цифры, дефисы и символы подчеркивания." },
            uniqueness: { message: "Должен быть уникальным." }
  validates :tv_link, format: { with: /\A[a-zA-Z0-9\-_]+\z/, message: "Может содержать только латинские буквы, цифры, дефисы и символы подчеркивания." }
  validates :header_boldness, :annotation_boldness, numericality: { only_integer: true, greater_than_or_equal_to: 100, less_than_or_equal_to: 900 }
  validates :header_font_size, :annotation_font_size, numericality: { only_integer: true, greater_than_or_equal_to: 8 }, allow_nil: true

  def self.enabled_for_department(department)
    ElectronicQueue.where(department: department, enabled: true).exists?
  end
end