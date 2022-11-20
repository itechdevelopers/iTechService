namespace :app do

  desc 'Mark expired faults'
  task mark_expired_faults: :environment do
    MarkExpiredFaults.()
  end

  desc 'Move repair parts of not_at_archive service_jobs to repair store'
  task stash_repair_parts: :environment do
    log = Logger.new('log/app_stash_repair_parts.log')
    # log = Logger.new(STDOUT)
    start_time = Time.current

    repair_store = Department.current.repair_store
    defect_sp_store = Department.current.defect_sp_store
    
    log.info "Task started at #{start_time}"

    RepairTask.includes(device_task: :service_job).where('service_jobs.location_id <> ?', Location.archive).find_each do |repair_task|
      repair_task.repair_parts.each do |repair_part|
        log.info "RepairPart [#{repair_part.id}] #{'-' * 10}"
        if repair_part.item.present?
          log.info "Product [#{repair_part.product.id}] #{repair_part.name} "
          if repair_task.pending?
            sp_store = repair_part.store

            log.info "Moving (#{repair_part.quantity}) to repair store"
            repair_part.store_item(sp_store).move_to(repair_store, repair_part.quantity)
          
            if repair_part.defect_qty > 0
              log.info "Moving defected (#{repair_part.defect_qty}) #{repair_part.name}"
              repair_part.store_item(sp_store).move_to(defect_sp_store, repair_part.defect_qty)
            end
          end
          if repair_task.done?
            log.info "Adding (#{repair_part.quantity}) to repair store"
            repair_part.store_item(repair_store).add(repair_part.quantity)
          end
        else
          log.info "!!! Item absent"
        end
      end
    end

    end_time = Time.current
    duration = (end_time - start_time) / 1.minute
    log.info "Task finished at #{end_time} and last #{duration} minutes."
    log.close
  end

  desc "Set default value for device's 'is_tray_present'"
  task set_tray_presence: :environment do
    ServiceJob.find_each do |service_job|
      service_job.update_column(:is_tray_present, true) if service_job.is_tray_present.nil?
    end
  end

  desc "Set ServiceJobs items"
  task set_service_jobs_items: :environment do
    SetServiceJobsItems.new.call
  end

  desc 'Resets Postgres auto-increment ID column sequences to fix duplicate ID errors'
  task :reset_sequences => :environment do
    Rails.application.eager_load!

    ActiveRecord::Base.descendants.each do |model|
      unless model.attribute_names.include?('id')
        Rails.logger.debug "Not resetting #{model}, which lacks an ID column"
        next
      end

      begin
        max_id = model.maximum(:id).to_i + 1
        result = ActiveRecord::Base.connection.execute(
          "ALTER SEQUENCE #{model.table_name}_id_seq RESTART #{max_id};"
        )
        Rails.logger.info "Reset #{model} sequence to #{max_id}"
      rescue => e
        Rails.logger.error "Error resetting #{model} sequence: #{e.class.name}/#{e.message}"
      end
    end
  end

  desc 'Clear retail store'
  task clear_retails_store: :environment do
    log = Logger.new('log/task_clear_retails_store.log')

    store = Store.retail.first

    store.store_items.find_each do |store_item|
      log.info "= Removing #{store_item.name} [#{store_item.code}] {#{store_item.features_s}} =="

      if store_item.feature_accounting
        log.info "==> #{store_item.destroy}"
      else
        log.info "==> #{store_item.update(quantity: 0)}"
      end
    end

    log.info "=== Finished ==="
  end
end
