module IconHelper
  def icon(*names)
    names.map! { |name| name.to_s.gsub('_','-') }
    names.map! do |name|
      name =~ /pull-(?:left|right)/ ? name : "fa fa-#{name}"
    end
    content_tag :i, nil, :class => names
  end
end