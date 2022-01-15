module MediaMenu
  class BaseController < ActionController::Base
    include ::Operation
    include ::RenderCell
    include ActionParams
    protect_from_forgery
  end
end
