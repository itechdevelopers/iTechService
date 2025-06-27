#frozen_string_literal: true

class MockOneCService
  def initialize
    Rails.logger.info '[Mock1C] Using Mock 1C Service for development'
  end

  def make_request(path, method: :post, body: nil)
    Rails.logger.info "[Mock1C] Mock request: #{method.upcase} #{path}"
    Rails.logger.info "[Mock1C] Mock request body: #{body}" if body

    # Simulate network delay
    sleep(rand(0.1..0.5))

    case path
    when '/UT/hs/ice_int/v1/UploadOrder/'
      mock_order_creation_response(body)
    when '/UT/hs/ice_int/v1/StatusID/'
      mock_device_status_response(body)
    when '/UT/hs/ice_int/v1/info/'
      mock_product_info_response(body)
    else
      { success: false, error: "Unknown mock endpoint: #{path}" }
    end
  end

  private

  def mock_order_creation_response(body)
    # Log the new fields for development testing
    if body && body['order']
      order_data = body['order']
      Rails.logger.info "[Mock1C] Order phone: #{order_data['phone']}"
      Rails.logger.info "[Mock1C] Order price: #{order_data['price']}"
      Rails.logger.info "[Mock1C] Order preorder: #{order_data['preorder']}"
      Rails.logger.info "[Mock1C] Order date: #{order_data['order_date']}"
    end
    
    # Generate a fake external order number
    external_number = "DEV-#{Time.current.strftime('%Y%m%d')}-#{rand(1000..9999)}"
    
    Rails.logger.info "[Mock1C] Generated fake external order number: #{external_number}"
    
    {
      success: true,
      data: {
        'external_number' => external_number,
        'status' => 'created',
        'message' => 'Заказ успешно создан в 1С (MOCK)'
      }
    }
  end

  def mock_device_status_response(body)
    return mock_device_not_found_response unless body&.dig('serialnumber')

    serial_number = body['serialnumber']
    Rails.logger.info "[Mock1C] Checking device status for: #{serial_number}"

    # Generate different mock responses based on serial number pattern
    mock_status = case serial_number.to_s.last
                  when '0', '2', '4', '6', '8'
                    mock_sold_device_response(serial_number)
                  when '1', '3', '5'
                    mock_accepted_device_response(serial_number)
                  when '7'
                    mock_written_off_device_response(serial_number)
                  else
                    mock_device_not_found_response
                  end

    {
      success: true,
      data: mock_status
    }
  end

  def mock_sold_device_response(serial_number)
    {
      'status' => 'Продан',
      'item' => "iPhone #{rand(12..15)} Pro (MOCK)",
      'serialnumber' => serial_number,
      'data' => (Time.current - rand(1..30).days).iso8601,
      'shop' => ['Филиал Центр (MOCK)', 'Филиал Север (MOCK)', 'Филиал Юг (MOCK)'].sample
    }
  end

  def mock_accepted_device_response(serial_number)
    {
      'status' => 'Принят',
      'item' => "MacBook #{['Air', 'Pro'].sample} (MOCK)",
      'serialnumber' => serial_number
    }
  end

  def mock_written_off_device_response(serial_number)
    {
      'status' => 'Списан',
      'item' => "iPad #{rand(9..11)} (MOCK)",
      'serialnumber' => serial_number,
      'data' => (Time.current - rand(5..60).days).iso8601,
      'shop' => 'Склад (MOCK)'
    }
  end

  def mock_device_not_found_response
    {
      'status' => 'Не найден'
    }
  end

  def mock_product_info_response(body)
    return mock_product_not_found_response unless body&.dig('Code')

    code = body['Code']
    department_code = body['DepartmentCode'] || 'default'
    
    Rails.logger.info "[Mock1C] Product lookup for code: #{code}, department: #{department_code}"

    # Generate different mock responses based on article pattern
    case code.to_s.downcase
    when /iphone/
      mock_iphone_product_response(code)
    when /macbook/
      mock_macbook_product_response(code)
    when /ipad/
      mock_ipad_product_response(code)
    else
      mock_generic_product_response(code)
    end
  end

  def mock_iphone_product_response(code)
    department_codes = ['00-000001', '00-000002', '00-000003']
    store_names = ['Океанский', 'Транзит Сахалин', 'Уссурийск', 'Хабаровск', 'Центральный']
    
    {
      success: true,
      data: {
        'name' => "iPhone #{rand(12..15)} Pro (MOCK)",
        'kind' => 'phone',
        'price' => "#{rand(80000..150000)}",
        'stores' => [
          { 
            'id' => rand(1..5), 
            'quantity' => rand(0..10),
            'department_code' => department_codes.sample,
            'name' => store_names.sample,
            'reserve' => rand(0..3)
          },
          { 
            'id' => rand(6..10), 
            'quantity' => rand(0..5),
            'department_code' => department_codes.sample,
            'name' => store_names.sample,
            'reserve' => rand(0..3)
          }
        ]
      }
    }
  end

  def mock_macbook_product_response(code)
    department_codes = ['00-000001', '00-000002', '00-000003']
    store_names = ['Океанский', 'Транзит Сахалин', 'Уссурийск', 'Хабаровск', 'Центральный']
    
    {
      success: true,
      data: {
        'name' => "MacBook #{['Air', 'Pro'].sample} (MOCK)",
        'kind' => 'laptop',
        'price' => "#{rand(120000..300000)}",
        'stores' => [
          { 
            'id' => rand(1..3), 
            'quantity' => rand(1..3),
            'department_code' => department_codes.sample,
            'name' => store_names.sample,
            'reserve' => rand(0..3)
          }
        ]
      }
    }
  end

  def mock_ipad_product_response(code)
    department_codes = ['00-000001', '00-000002', '00-000003']
    store_names = ['Океанский', 'Транзит Сахалин', 'Уссурийск', 'Хабаровск', 'Центральный']
    
    {
      success: true,
      data: {
        'name' => "iPad #{rand(9..11)} (MOCK)",
        'kind' => 'tablet',
        'price' => "#{rand(50000..100000)}",
        'stores' => [
          { 
            'id' => rand(1..5), 
            'quantity' => rand(2..8),
            'department_code' => department_codes.sample,
            'name' => store_names.sample,
            'reserve' => rand(0..3)
          }
        ]
      }
    }
  end

  def mock_generic_product_response(code)
    department_codes = ['00-000001', '00-000002', '00-000003']
    store_names = ['Океанский', 'Транзит Сахалин', 'Уссурийск', 'Хабаровск', 'Центральный']
    
    {
      success: true,
      data: {
        'name' => "Product #{code} (MOCK)",
        'kind' => 'accessory',
        'price' => "#{rand(1000..50000)}",
        'stores' => [
          { 
            'id' => rand(1..3), 
            'quantity' => rand(0..15),
            'department_code' => department_codes.sample,
            'name' => store_names.sample,
            'reserve' => rand(0..3)
          }
        ]
      }
    }
  end

  def mock_product_not_found_response
    {
      success: false,
      error: 'Product not found in 1C (MOCK)'
    }
  end
end
