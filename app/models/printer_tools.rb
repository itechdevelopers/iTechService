module PrinterTools

  def self.print_file(filepath, type: nil, height: nil, printer: nil)
    if File.exists? filepath
      options = '-o PageCutType=1PartialCutPage'
      case type&.to_sym
        when :sale_check then options << " -o media=Custom.72x#{height || 200}mm"
        when :waiting_client then options << " -o media=Custom.72x#{height || 200}mm -o orientation-requested=6"
        when :ticket then options << ' -o media=Custom.72x90mm'
        when :quick_order then options << ' -o media=Custom.72x90mm'
        when :tags then options = ' -d tags'
        # when :tags then options = " -d 'tags' -o media=Custom.29mmx20mm"
        else options << ' -o media=Custom.72x90mm'
      end
      options << " -d #{printer}" if printer
      puts "#{options} #{filepath}"
      system "lp #{options} #{filepath}"
    else
      puts "File not found #{filepath}"
    end
  end

end
