module Apidiesel

  # Wrapper for API requests
  class Request
    attr_accessor :action, :parameters, :response_body, :http_request, :http_response, :metadata, :result

    # @param [Apidiesel::Action] action
    # @param [Hash] parameters
    # @param [Hash] metadata
    def initialize(action:, parameters:, metadata: {})
      @action     = action
      @parameters = parameters
      @metadata   = metadata
    end

    def response_body
      @response_body || http_response.try(:body)
    end

    def process_response
      @result = action.process_response(response_body)
    end
  end
end
