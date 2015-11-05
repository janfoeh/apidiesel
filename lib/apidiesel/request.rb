module Apidiesel

  # Wrapper for API requests
  class Request
    attr_accessor :action, :parameters, :response_body, :http_request, :result

    # @param [Apidiesel::Action] action
    # @param [Hash] parameters
    def initialize(action:, parameters:)
      @action      = action
      @parameters  = parameters
    end

    def response_body
      @response_body || http_request.try(:body)
    end

    def process_response
      @result = action.process_response(response_body)
    end
  end
end
