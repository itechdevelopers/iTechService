module Service
  module Job::Cell
    class Feedbacks < BaseCell
      private

      def feedbacks
        model.feedbacks.new_first
      end
    end
  end
end