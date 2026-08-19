module Service
  module Feedback::Cell
    class List < BaseCell
      include IndexCell
      include ActionView::Helpers::DateHelper

      private

      def feedbacks
        model
      end

      # Один и тот же список рендерится дважды: в popover'е «трубки» и в панели
      # дашборда. Без разных префиксов на странице оказались бы два элемента с
      # одинаковым id, и точечное удаление обработанной трубки било бы мимо.
      def id_prefix
        options[:id_prefix].to_s
      end
    end
  end
end
