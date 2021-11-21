# encoding: utf-8
class ProductTagPdf < Prawn::Document
  require 'prawn/measurement_extensions'
  require 'barby/barcode/ean_13'
  require 'barby/outputter/prawn_outputter'

  def initialize(item, view, options={})
    # TODO: store size and margin in settings or settings .yml file
    super page_size: [30.mm, 20.mm], page_layout: :portrait, margin: [1.mm,2.mm,2.mm,2.mm]
    # super page_size: [41.mm, 20.mm], page_layout: :portrait, margin: [1.mm, 2.mm, 2.mm, 13.mm]
    @item = item
    @view = view
    font_families.update 'DroidSans' => {
      normal: "#{Rails.root}/app/assets/fonts/droidsans-webfont.ttf",
      bold: "#{Rails.root}/app/assets/fonts/droidsans-bold-webfont.ttf"
    }
    font 'DroidSans'
    title = ''
    title << "#{item.code}: " if options[:price].blank?
    title << item.name
    # title << "(#{item.features.map(&:value).join(', ')})" if item.feature_accounting
    price = if options.key? :price
              options[:price].in?([true, 'true']) ? item.retail_price : options[:price]
            else
              nil
            end
    if options[:quantity].present?
      options[:quantity].to_i.times { item_tag(title, item.barcode_num, price) }
    else
      item_tag title, item.barcode_num, price
      item_tag title, item.barcode_num, price
    end
  end

  private

  def currency_str(number)
    @view.number_to_currency number, precision: 0, delimiter: ' ', separator: ',', unit: ''
  end

  def draw_barcode(number, options={})
    outputter = Barby::PrawnOutputter.new Barby::EAN13.new(number.chop)
    outputter.annotate_pdf self, options.merge(height: 14, x: 1.mm, xdim: 0.75)
  end

  def item_tag(title, barcode_num, price=nil)
    if price.nil?
      font_size 6
      text title, align: :center
      draw_barcode barcode_num, margin: 8
      move_cursor_to 7
      text barcode_num, character_spacing: 2
    else
      font_size 5
      text title, align: :center
      move_down 1
      stroke { horizontal_line 0, 3.cm }
      move_cursor_to 29
      font_size 10 do
        text currency_str(price).to_s, align: :center, style: :bold
        move_up 8
        text @view.t('number.currency.format.unit'), align: :right, size: 6
      end
      draw_barcode barcode_num, margin: 5
      move_cursor_to 4
      font_size 4 do
        text barcode_num, character_spacing: 3.7
      end
    end
  end
end
