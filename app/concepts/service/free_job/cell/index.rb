module Service
  module FreeJob::Cell
    class Index < BaseCell
      private

      include IndexCell
      include Kaminari::Cells
      include UsersHelper
      include ActionView::Helpers::FormOptionsHelper
      include DepartmentsHelper

      def title
        t '.index'
      end

      def free_job_rows
        cell(Preview, collection: model).()
      end

      def free_jobs_table
        cell(UserTable, collection: collection).()
      end

      def new_link
        link_to icon(:plus), new_service_free_job_path, class: 'btn btn-success btn-large'
      end

      def date_placeholder
        t 'attributes.date'
      end

      def performer_placeholder
        t_attribute :performer
      end

      def pagination
        paginate collection, theme: 'bootstrap-2', remote: true
      end

      def datepicker_data
        {
          'date-format': 'dd.mm.yyyy',
          'date-weekStart': 1
        }
      end
    end
  end
end
