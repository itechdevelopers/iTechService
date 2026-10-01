# Время возврата в новой приёмке: варианты «через N часов / дней» видны сразу чипами, а ручной
# выбор даты — то же поле с календарём, что у datetime_quick_select. Время чипов считается при
# отрисовке страницы в часовом поясе сотрудника — как у пунктов «через» в старой приёмке.
class ReturnAtPickerInput < SimpleForm::Inputs::Base
  HOURS = (1..5).freeze
  DAYS = (1..5).freeze

  def input(_wrapper_options = nil)
    template.content_tag(:div, class: 'return-at-picker') do
      chips_row(HOURS) { |count| [I18n.t('datetime_select.x_hours', count: count), count.hours.since] } +
        chips_row(DAYS) { |count| [I18n.t('datetime_select.x_days', count: count), count.days.since] } +
        manual_input
    end
  end

  private

  # tabindex -1: Tab идёт от поля к полю, а не по каждому чипу
  def chips_row(counts)
    template.content_tag(:div, class: 'return-at-picker__row') do
      template.safe_join(counts.map do |count|
        label, time = yield(count)
        template.button_tag("#{I18n.t('in_time')} #{label}",
                            type: 'button', name: nil, tabindex: -1, class: 'return-at-picker__chip',
                            data: { value: time.strftime('%d.%m.%Y %H:%M') })
      end)
    end
  end

  def manual_input
    template.content_tag(:div, class: 'return-at-picker__manual') do
      template.content_tag(:span, 'или вручную:', class: 'return-at-picker__manual-label') +
        template.content_tag(:div, class: 'datetimepicker input-append') do
          @builder.input_field(attribute_name, as: :string, class: 'return-at-picker__input', autocomplete: 'off') +
            template.content_tag(:span,
                                 template.content_tag(:i, nil, data: { time_icon: 'icon-time', date_icon: 'icon-calendar' }),
                                 class: 'add-on')
        end
    end
  end
end
