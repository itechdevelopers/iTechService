#frozen_string_literal: true

class ProductFinderService < OneCBaseClient
  attr_reader :article, :department_id, :path

  def initialize(article, department_id)
    super()
    @article = article
    @department_id = department_id
    @path = "/UT/hs/ice_int/v1/info/"
  end

  def call
    # Use fallback department when department_id is nil
    dept_id = @department_id.present? ? @department_id : Department.current.id
    department = Department.find(dept_id)
    
    body = {
      "Code" => @article,
      "DepartmentCode" => department.code_one_c
    }
    
    one_c_response = make_request(path, method: :post, body: body)

    return { status: 'not_found', message: one_c_response[:error] } unless one_c_response[:success]
    
    { status: 'found' }.merge(one_c_response[:data]) 
  end
end
