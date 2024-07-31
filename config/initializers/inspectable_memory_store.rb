module ActiveSupport
  module Cache
    class MemoryStore

      include ActionView::Helpers::NumberHelper

      def size
        number_to_human_size(@cache_size)
      end
    end
  end
end