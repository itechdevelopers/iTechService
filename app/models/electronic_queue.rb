class ElectronicQueue < ApplicationRecord
  belongs_to :department
  has_many :queue_items
  has_many :elqueue_windows, dependent: :destroy

  validates :department, presence: true
  validates :queue_name, presence: true
  validates :ipad_link,
            format: { with: /\A[a-zA-Z0-9\-_]+\z/, message: "Может содержать только латинские буквы, цифры, дефисы и символы подчеркивания." },
            uniqueness: { message: "Должен быть уникальным." }
  validates :tv_link, format: { with: /\A[a-zA-Z0-9\-_]+\z/, message: "Может содержать только латинские буквы, цифры, дефисы и символы подчеркивания." },
            uniqueness: { message: "Должен быть уникальным." }
  validates :header_boldness, :annotation_boldness, numericality: { only_integer: true, greater_than_or_equal_to: 100, less_than_or_equal_to: 900 }
  validates :header_font_size, :annotation_font_size, numericality: { only_integer: true, greater_than_or_equal_to: 8 }, allow_nil: true

  after_create :create_elqueue_windows

  scope :enabled, -> { where(enabled: true) }

  def self.enabled_for_department(department)
    ElectronicQueue.where(department: department, enabled: true).exists?
  end

  def move
    shuffled_window_ids = shuffle_windows(elqueue_windows.active_free.pluck(:id))
    shuffled_window_ids.each do |window_id|
      window = ElqueueWindow.find(window_id)
      window.next_waiting_client&.start_service(window)
    end
  end

  def create_elqueue_windows
    (1..windows_count).each do |i|
      self.elqueue_windows.create(window_number: i, is_active: false)
    end
  end

  private

  def shuffle_windows(ary)
    result = []

    while ary.any?
      random_index = rand(ary.length)
      result << ary.delete_at(random_index)
    end

    result
  end
end
