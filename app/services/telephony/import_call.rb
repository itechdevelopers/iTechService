# frozen_string_literal: true
module Telephony
  class ImportCall
    FIELDS = %w[call_unique_id started_at caller_number called_number answered_extension direction status duration billsec recording_path].freeze
    def self.call(attributes)
      attrs = attributes.slice(*FIELDS).symbolize_keys
      attrs[:caller_number] = Number.normalize(attrs[:caller_number]) || attrs[:caller_number].to_s
      attrs[:answered_extension] = Number.normalize(attrs[:answered_extension]) || attrs[:answered_extension]
      attrs[:called_number] = Number.normalize(attrs[:called_number]) || attrs[:called_number]
      record = PhoneCall.find_or_initialize_by(call_unique_id: attrs.delete(:call_unique_id))
      record.with_lock do
        if record.new_record?
          caller = User.where('telephony_extension = :number OR pbx_extension = :number', number: attrs[:caller_number]).first
          record.caller_user = caller
          record.caller_employee_name = caller&.full_name
        end
        # Late browser correlation can enrich an existing CDR; retries must not
        # reattribute an old call after an extension is reassigned.
        if record.new_record? || (record.answered_extension.blank? && attrs[:answered_extension].present?)
          extension = attrs[:answered_extension]
          user = extension.present? ? User.where('telephony_extension = :extension OR pbx_extension = :extension', extension: extension).first : nil
          record.answered_user = user
          record.answered_employee_name = user&.full_name
        end
        record.assign_attributes(attrs)
        record.save!
      end
      record
    rescue ActiveRecord::RecordNotUnique
      retry
    end
  end
end
