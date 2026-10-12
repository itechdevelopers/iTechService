# frozen_string_literal: true
module Telephony
  class ImportCall
    FIELDS = %w[call_unique_id started_at caller_number called_number answered_extension direction status duration billsec recording_path].freeze
    def self.employee_for(number)
      return nil if number.blank?
      PhoneLabel.find_by(phone_number: number)&.user || User.where('telephony_extension = :n OR pbx_extension = :n', n: number).first
    end

    def self.call(attributes)
      source = attributes.fetch('source', 'cdr')
      raise ArgumentError unless %w[ami cdr].include?(source)
      uid = attributes.fetch('call_unique_id')
      raise ArgumentError unless uid.to_s.match?(/\A\d{10}\.\d+\z/)
      attrs = attributes.slice(*FIELDS).symbolize_keys.except(:call_unique_id)
      %i[caller_number called_number answered_extension].each do |key|
        attrs[key] = Number.normalize(attrs[key]) || attrs[key] if attrs.key?(key)
      end
      # A savepoint isolates a concurrent unique violation from the batch's
      # outer transaction. Retry the whole savepoint, not an aborted transaction.
      attempts = 0
      begin
        record = nil
        PhoneCall.transaction(requires_new: true) do
          # CDR for a destination leg enriches the same logical AMI conversation.
          record = PhoneCall.find_by(call_unique_id: uid)
          record ||= PhoneCall.where('legs @> ?::jsonb', [{ unique_id: uid }].to_json).first if source == 'cdr'
          record ||= PhoneCall.new(call_unique_id: uid)
          record.with_lock do
            if source == 'ami'
              aliases = attributes.fetch('supersedes', [])
              raise ArgumentError unless aliases.is_a?(Array) && aliases.length <= 100 && aliases.all? { |id| id.to_s.match?(/\A\d{10}\.\d+\z/) && id != uid }
              # Retire provisional AMI rows after routing-channel correlation.
              # Preserve finalized CDR rows when historical correlation is uncertain.
              PhoneCall.where(call_unique_id: aliases, finalized_at: nil).lock.each(&:destroy!)
              stamp = Time.iso8601(attributes.fetch('observed_at'))
              raise ArgumentError if stamp > Time.current + 30.seconds
              return record if record.finalized_at || (record.live_updated_at && record.live_updated_at >= stamp)
              raise ArgumentError unless %w[ringing talking ended interrupted].include?(attrs[:status])
              record.live_updated_at = stamp
              record.legs = attributes.fetch('legs', [])
            else
              raise ArgumentError unless %w[answered missed busy failed].include?(attrs[:status])
              # Failed group/transfer legs must not erase a successful answer.
              if record.status == 'answered' && attrs[:status] != 'answered'
                attrs = attrs.slice(:recording_path).reject { |_, value| value.blank? }
              end
              record.finalized_at ||= Time.current
            end
            if record.new_record?
              caller = employee_for(attrs[:caller_number])
              record.caller_user = caller
              record.caller_employee_name = caller&.full_name
            end
            extension = attrs[:answered_extension]
            if extension.present? && (record.answered_extension.blank? || record.finalized_at_changed?)
              employee = employee_for(extension)
              record.answered_user = employee
              record.answered_employee_name = employee&.full_name
            elsif record.answered_extension.present?
              attrs.delete(:answered_extension) # Keep number and snapshot together on retries.
            end
            record.assign_attributes(attrs)
            record.save!
          end
        end
        record
      rescue ActiveRecord::RecordNotUnique
        attempts += 1
        retry if attempts < 3
        raise
      end
    end
  end
end
