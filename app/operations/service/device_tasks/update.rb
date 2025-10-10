module Service
  module DeviceTasks
    class Update < ATransaction
      step :validate
      check :check_remnants
      step :save
      tee :notify

      private

      def validate(params, device_task)
        # Extract service_job_attributes for later processing
        @service_job_attributes = params.delete(:service_job_attributes)

        # First, update only the device task attributes (without service job)
        device_task.attributes = params

        device_task.valid? ? Success(device_task) : Failure(device_task)
      end

      def check_remnants(device_task)
        store = Department.current.spare_parts_store

        device_task.repair_tasks.each do |repare_task|
          repare_task.repair_parts.each do |repair_part|
            quantity_need = repair_part.spare_part_defects.to_a.sum { |spd| spd.new_record? ? spd.qty : 0 }
            quantity_need += repair_part.quantity if repare_task.new_record?

            if repair_part.store_item(store).quantity < quantity_need
              device_task.errors[:base] << I18n.t('device_tasks.errors.insufficient_spare_parts',
                                                  store: store.name, spare_part: repair_part.name)
            end
          end
        end

        device_task.errors.empty?
      end

      def save(device_task, user)
        ActiveRecord::Base.transaction do
          begin
            if device_task.is_repair?
              device_task.repair_tasks.each do |repare_task|
                repare_task.repair_parts.each do |repair_part|
                  repair_part.stash if repare_task.new_record?

                  if repair_part.is_warranty == '1'
                    repair_part.spare_part_defects.build item_id: repair_part.item_id,
                                                         qty: repair_part.quantity,
                                                         is_warranty: true,
                                                         contractor_id: repair_part.contractor_id
                  end

                  repair_part.spare_part_defects.each do |spare_part_defect|
                    if spare_part_defect.new_record?
                      spare_part_defect.item_id ||= repair_part.item_id
                      move_defected spare_part_defect, device_task, user
                    end
                  end
                end
              end
            end

            device_task.save!

            # Now update the service job AFTER the device task is saved
            if @service_job_attributes.present?
              service_job = device_task.service_job
              # Reload to get fresh associations after device task save
              service_job.reload
              service_job.attributes = @service_job_attributes
              service_job.save!
            end
          rescue ActiveRecord::Rollback, ActiveRecord::RecordInvalid
            return Failure(device_task)
          end
        end

        Success(device_task)
      end

      def notify(device_task, user, params)
        Service::DeviceSubscribersNotificationJob.perform_later(device_task.service_job_id, user.id, params)
      end

      def move_defected(spare_part_defect, device_task, user)
        comment = "Списание брака при ремонте. Талон: #{device_task.ticket_number}. Исполнитель: #{user.short_name}."

        if spare_part_defect.is_warranty?
          spare_part_defect.store_item(device_task.department.defect_sp_store).add(spare_part_defect.qty)
        else
          movement_act = MovementAct.create store_id: device_task.department.spare_parts_store.id,
                                            dst_store_id: device_task.department.defect_sp_store.id,
                                            user_id: user.id,
                                            comment: comment,
                                            date: DateTime.current

          movement_act.movement_items.create(item_id: spare_part_defect.item_id, quantity: spare_part_defect.qty)
          movement_act.post
        end
      end
    end
  end
end
