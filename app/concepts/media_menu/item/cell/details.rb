module MediaMenu
  module Item::Cell
    class Details < Card
      private

      property :description

      def image
        image_tag image_file, width: 176
      end

      def year
        "#{t_attribute(:year)}: #{model.year}"
      end

      def genre
        "#{t_attribute(:genre)}: #{model.genre}"
      end

      def category
        category_name = model.category ? t(".category/#{model.category}") : '-'
        "#{t_attribute(:category)}: #{category_name}"
      end

      def selection_button_class
        'btn btn-primary'.freeze
      end
    end
  end
end