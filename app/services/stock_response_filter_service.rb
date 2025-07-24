# frozen_string_literal: true

class StockResponseFilterService
  attr_reader :response, :user

  def initialize(response, user)
    @response = response
    @user = user
  end

  def call
    return response unless response[:status] == 'found' && response["stores"].present?

    # Always add display_text to all stores, regardless of user permissions
    add_display_text_to_stores
  end

  private

  def can_view_exact_stock?
    ProductPolicy.new(user, Product).view_exact_department_stock?
  end

  def add_display_text_to_stores
    department_colors = fetch_department_colors
    
    filtered_response = response.dup
    filtered_response["stores"] = response["stores"].map do |store|
      store.dup.tap do |filtered_store|
        # Generate display text with styling
        color = department_colors[store["department_code"]] || '#f0f0f0'
        text_color = get_contrast_color(color)
        
        # Generate multi-line display content with visual indicators
        store_line = "#{store["name"]} (#{store["department_code"]})"
        reserve_line = "📦 В резерве: #{store["reserve"]} шт."
        
        if can_view_exact_stock?
          # Show exact quantities for authorized users
          stock_line = "✅ В наличии: #{store["quantity"]} шт."
          display_content = "#{store_line}<br>#{stock_line}<br>#{reserve_line}"
        else
          # Show availability status for unauthorized users, but keep reserve info
          if store["quantity"].to_i > 0
            stock_line = "✅ Доступно на филиале"
          else
            stock_line = "❌ Недоступно на филиале"
          end
          display_content = "#{store_line}<br>#{stock_line}<br>#{reserve_line}"
          
          # Remove exact quantity from unauthorized response
          filtered_store.delete("quantity")
        end
        
        # Generate complete HTML span with styling (increased padding for multi-line)
        filtered_store["display_text"] = "<span class='stock-line' style='background-color: #{color}; color: #{text_color}; padding: 4px 8px; border-radius: 3px; display: inline-block; margin: 2px 0;'>#{display_content}</span>"
      end
    end
    
    filtered_response
  end

  def fetch_department_colors
    # Get department colors mapping
    departments = Department.with_one_c_code.includes(:city)
    color_mapping = {}
    
    departments.each do |dept|
      color_mapping[dept.code_one_c] = dept.color || '#f0f0f0'
    end
    
    color_mapping
  end

  def get_contrast_color(hex_color)
    # Remove # if present
    hex = hex_color.gsub('#', '')
    
    # Convert to RGB
    r = hex[0..1].to_i(16)
    g = hex[2..3].to_i(16) 
    b = hex[4..5].to_i(16)
    
    # Calculate luminance
    luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
    
    # Return white text for dark backgrounds, black for light
    luminance > 0.5 ? '#000000' : '#ffffff'
  end
end
