require 'rmagick'

class CasePicturePdf < Prawn::Document
  require 'prawn/measurement_extensions'

  def initialize(file, params)
    super page_size: 'A4', page_layout: :portrait
    is_contour = params['contour']
    model = params['model']
    case model
      when 'iphone4'
        @width = 62.5.mm
        @height = 122.mm #117.5.mm # to correct
        @depth = 13.mm
      else
        @width = 62.5.mm
        @height = 133.mm
        @depth = 12.mm
    end
    @r = 5.mm
    @r2 = 5.mm
    @x1 = (margin_box.width - @width) / 2
    @y1 = (margin_box.height + @height) / 2
    @x2 = @x1 + @width
    @y2 = @y1 - @height
    @x3 = @x1 - @depth
    @y3 = @y1 + 6.mm
    @x4 = @x2 + @depth
    @y4 = @y2 - 6.mm
    @x5 = @x1 + 9.mm
    @x6 = @x2 - 9.mm
    @y5 = @y1 - @r
    @y6 = @y2 + @r

    image = Magick::Image.read(file).first
    image.flop!
    image.write file

    save_graphics_state do
      soft_mask do
        fill_color 'ffffff'
        fill_and_stroke do
          draw_shape
        end
      end
      image file, width: @x4 - @x3, height: @y3 - @y4, at: [@x3, @y3]
      # fill_color 'ff0000'
      # fill_and_stroke { draw_shape }
    end
    stroke { draw_contour } if is_contour
  end

  private

  def draw_shape
    # left side
    line [@x1, @y5], [@x1, @y3]
    line_to @x3+@r2, @y3
    curve_to [@x3, @y3-@r2], bounds: [[@x3, @y3], [@x3, @y3-@r2]]
    line_to @x3, @y4+@r2
    curve_to [@x3+@r2, @y4], bounds: [[@x3, @y4], [@x3+@r2, @y4]]
    line_to @x1, @y4
    line_to @x1, @y6

    # bottom side
    curve_to [@x5, @y2], bounds: [[@x1+1.mm, @y2], [@x5, @y2]]
    line_to @x5, @y2 - 2.mm
    line_to @x6, @y2 - 2.mm
    line_to @x6, @y2
    curve_to [@x2, @y6], bounds: [[@x6, @y2], [@x2-1.mm, @y2]]

    # right side
    line_to @x2, @y4
    line_to @x4-@r2, @y4
    curve_to [@x4, @y4+@r2], bounds: [[@x4-@r2, @y4], [@x4, @y4]]
    line_to @x4, @y3-@r2
    curve_to [@x4-@r2, @y3], bounds: [[@x4, @y3-@r2], [@x4, @y3]]
    line_to @x2, @y3
    line_to @x2, @y5

    # top side
    curve_to [@x6, @y1], bounds: [[@x2, @y5], [@x2, @y1-1.mm]]
    line_to @x6, @y1 + 2.mm
    line_to @x5, @y1 + 2.mm
    line_to @x5, @y1
    curve_to [@x1, @y5], bounds: [[@x5, @y1], [@x1+1.mm, @y1]]
  end

  def draw_contour
    contour = 0.2.mm
    @x1, @x2 = @x1 + contour, @x2 - contour
    @y1, @y2 = @y1 + contour, @y2 - contour
    @x3, @x4 = @x3 - contour, @x4 + contour
    @y3, @y4 = @y3 + contour, @y4 - contour
    @x5, @x6 = @x5 - contour, @x6 + contour
    @y5, @y6 = @y5 + contour*8, @y6 - contour*8
    draw_shape
  end

end