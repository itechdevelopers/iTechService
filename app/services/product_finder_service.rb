#frozen_string_literal: true

class ProductFinderService < OneCBaseClient
  attr_reader :article, :path

  def initialize(article)
    super()
    @article = article
    @path = "/api/products/#{article}"
  end

  def call
    one_c_response = make_request(path, method: :get)

    return { status: 'not_found', message: one_c_response[:error] } unless one_c_response[:success]
    
    { status: 'found' }.merge(one_c_response[:data]) 
  end
end
