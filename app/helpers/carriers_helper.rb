module CarriersHelper
  # Логотип + название оператора для списков выбора. Слот под логотип одной ширины
  # рисуется и у операторов без картинки («НЕТ СИМКИ», «ДРУГОЙ»), чтобы названия
  # в списке стояли ровным столбиком, — но только если логотип есть хоть у кого-то.
  def carrier_label(carrier)
    return '-' if carrier.nil?

    parts = []
    if carrier_logos_present?
      logo = carrier.logo? ? image_tag(carrier.logo.small.url, alt: '', class: 'carrier-label__logo') : nil
      parts << content_tag(:span, logo, class: 'carrier-label__logo-slot')
    end
    parts << content_tag(:span, carrier.name, class: 'carrier-label__name')

    content_tag(:span, safe_join(parts), class: 'carrier-label')
  end

  private

  def carrier_logos_present?
    return @carrier_logos_present if defined?(@carrier_logos_present)

    @carrier_logos_present = Carrier.where.not(logo: [nil, '']).exists?
  end
end
