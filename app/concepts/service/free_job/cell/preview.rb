module Service
  module FreeJob::Cell
    class Preview < BaseCell
      private

      include ModelCell
      include DepartmentsHelper

      property :id, :client_short_name, :performer_short_name, :receiver_short_name, :task

      def department
        department_tag model.department
      end

      def performed_at
        I18n.l model.performed_at, format: :date_time
      end

      def client
        link_to client_short_name, model.client
      end

      def performer
        link_to performer_short_name, model.performer
      end

      def receiver
        link_to receiver_short_name, model.receiver
      end

      def link_to_show
        link_to icon('eye'), model, class: 'btn btn-info btn-small'
      end

      def link_to_edit
        link_to icon(:edit), edit_service_free_job_path(id), class: 'btn btn-small'
      end

      def link_to_destroy
        link_to icon(:trash), model, method: 'delete', data: {confirm: t('helpers.links.confirm', default: 'Are you sure?')}, class: 'btn btn-danger btn-small'
      end
    end
  end
end
