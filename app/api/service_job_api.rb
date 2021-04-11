class ServiceJobApi < Grape::API
  version 'v1', using: :path

  before { authenticate! }

  resource 'service_jobs' do
    route_param :id, type: Integer do
      desc 'Show service job info'
      get do
        service_job = find_record ServiceJob, :read
        present service_job
      end

      resource 'notes' do
        desc 'Show service job notes'
        get do
          service_job = find_record ServiceJob.includes(:device_notes), :read
          present_record service_job.device_notes
        end

        desc 'Create service job note'
        params do
          requires :content, type: String
        end
        post do
          service_job = find_record ServiceJob.includes(:device_notes), :read
          attributes = action_params.merge(user_id: current_user.id)
          new_note = service_job.device_notes.build(attributes)
          new_note.save ? present_record(new_note) : present_record_errors(new_note)
        end
      end
    end
  end

  # desc 'Move device to archive'
  # put 'archive_devices/:id', requirements: { id: /[0-9]*/ } do
  #   authorize :modify, ServiceJob
  #   service_job = ServiceJob.find params[:id]
  #   if service_job.update_attributes location_id: Location.archive.id
  #     present service_job
  #   else
  #     error!({error: service_job.errors.full_messages.join('. ')}, 403)
  #   end
  # end

  # desc 'Move device'
  # params do
  #   requires :move
  # end
  # put 'devices/:id', requirements: { id: /[0-9]*/ } do
  #   authorize :modify, ServiceJob
  #   if (location = params[:move]).present?
  #     if Location.respond_to? location+'_id'
  #       service_job = ServiceJob.find params[:id]
  #       if service_job.update_attributes location_id: Location.send(location+'_id')
  #         present service_job
  #       else
  #         error!({error: service_job.errors.full_messages.join('. ')}, 403)
  #       end
  #     else
  #       error!({error: I18n.t('api.service_jobs.errors.invalid_action')}, 403)
  #     end
  #   else
  #     error!({error: I18n.t('api.service_jobs.errors.no_action')}, 403)
  #   end
  # end

  desc 'Check device status'
  get 'check_device_status/:ticket_number', requirements: {ticket_number: /[0-9]+/} do
    authorize :read, ServiceJob
    if (service_job = ServiceJob.find_by_ticket_number(params[:ticket_number])).present?
      service_job.status_info
    else
      {status: 'not_found'}
    end
  end
end