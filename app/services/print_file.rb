class PrintFile
  attr_reader :filepath, :type, :height, :printer

  def initialize(filepath, type: nil, height: nil, printer: nil)
    @filepath = filepath
    @type = type
    @height = height
    @printer = printer
  end

  def call
    if File.exists? filepath
      options = '-o PageCutType=1PartialCutPage'
      case type&.to_sym
        when :sale_check then options << " -o media=Custom.72x#{height || 200}mm"
        when :ticket then options << ' -o media=Custom.72x90mm'
        when :quick_order then options << ' -o media=Custom.72x120mm'
        when :trade_in then options << ' -o media=Custom.80x160mm'
        when :tags then options = ' -d tags'
        else options << ' -o media=Custom.72x90mm'
      end
      options << " -d #{printer}" unless printer.blank?
      puts "Printing file #{filepath} with options: #{options} "
      result = system "lp #{options} #{filepath}"
    else
      result = "File not found #{filepath}"
    end
    puts result
    result
  end

  def self.call(*args)
    new(*args).call
  end
end