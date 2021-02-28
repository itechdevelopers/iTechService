module Service
  module FreeJob::Cell
    class UserTable < BaseCell
      private
      include IndexCell
      include Kaminari::Cells
      include UsersHelper
      include ActionView::Helpers::FormOptionsHelper
      include DepartmentsHelper

      def free_job_rows
        cell(Preview, collection: model).()
      end

      def pagination
        paginate collection, theme: 'bootstrap-2', remote: true
      end
    end
  end
end
