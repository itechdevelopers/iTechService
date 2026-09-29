# frozen_string_literal: true

class LegalEntity < ApplicationRecord
  # Параметр Setting → атрибут организации. Документы читают реквизиты из параметров,
  # поэтому привязка к подразделению пишет их в строки этого подразделения.
  SETTING_FIELDS = {
    'organization' => :name,
    'ogrn_inn' => :ogrn_inn,
    'legal_address' => :legal_address
  }.freeze

  has_many :departments, dependent: :restrict_with_error

  scope :ordered, -> { order(:name) }

  validates :name, :ogrn_inn, :legal_address, presence: true

  # В той же транзакции, что и сохранение: параметры привязанных подразделений
  # не должны расходиться с организацией даже на время.
  after_update :sync_linked_departments, if: :requisites_changed?

  def self.unlink!(department)
    transaction do
      department.update_column(:legal_entity_id, nil)
      Setting.where(department_id: department.id, name: SETTING_FIELDS.keys).destroy_all
    end
  end

  # update_column, а не update!: валидации Department (url у main/branch,
  # only_one_main) к привязке отношения не имеют и на старых записях могут не пройти.
  def link!(department)
    transaction do
      department.update_column(:legal_entity_id, id)
      write_settings!(department)
    end
  end

  private

  def requisites_changed?
    (saved_changes.keys & SETTING_FIELDS.values.map(&:to_s)).any?
  end

  def sync_linked_departments
    departments.each { |department| write_settings!(department) }
  end

  def write_settings!(department)
    SETTING_FIELDS.each do |setting_name, attribute|
      setting = Setting.find_or_initialize_by(name: setting_name, department_id: department.id)
      setting.value = public_send(attribute)
      setting.value_type = 'string'
      setting.presentation = I18n.t("settings.#{setting_name}")
      setting.save!
    end
  end
end
