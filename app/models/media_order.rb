# frozen_string_literal: true

class MediaOrder < ApplicationRecord
  def header
    [
      "#{time.strftime('%d.%m.%Y %H:%M:%S')}, #{phone}, #{name}\n0\n\n",
      "Заказ от #{time.strftime('%d.%m.%Y %H:%M:%S.')}\n\n",
      "Имя: #{name}\n",
      "Телефон: #{phone}\n\n\n"
    ].join
  end

  def full_content
    header + content
  end
end
