# frozen_string_literal: true

# Реквизиты подразделения в том виде, в каком их напечатают документы: своя строка
# параметра, а без неё — общая. Своя строка побеждает, даже если в ней пусто, —
# так же читает Setting.get_value.
class DepartmentRequisites
  Field = Struct.new(:name, :value, :own)

  attr_reader :fields

  def self.by_department(departments)
    settings = Setting.where(name: LegalEntity::SETTING_FIELDS.keys,
                             department_id: departments.map(&:id) + [nil]).to_a
    global = settings.select { |setting| setting.department_id.nil? }

    departments.each_with_object({}) do |department, result|
      own = settings.select { |setting| setting.department_id == department.id }
      result[department.id] = new(own, global)
    end
  end

  def self.global
    new([], Setting.where(name: LegalEntity::SETTING_FIELDS.keys, department_id: nil).to_a)
  end

  def initialize(own_settings, global_settings)
    own = own_settings.index_by(&:name)
    global = global_settings.index_by(&:name)

    @fields = LegalEntity::SETTING_FIELDS.keys.map do |name|
      setting = own[name] || global[name]
      Field.new(name, setting&.value.to_s, own.key?(name))
    end
  end

  # Совпадают ли параметры подразделения с привязанной организацией — не совпадут,
  # если строку поправили или удалили вручную на странице «Параметры».
  def match?(legal_entity)
    fields.all? do |field|
      field.own && field.value == legal_entity.public_send(LegalEntity::SETTING_FIELDS[field.name]).to_s
    end
  end
end
