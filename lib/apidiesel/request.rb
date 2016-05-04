module Apidiesel

  # Wrapper for API requests
  class Request
    attr_accessor :action, :action_arguments, :parameters, :url, :response_body, :http_request, :http_response, :metadata, :result

    # @param [Apidiesel::Action] action
    # @param [Hash] action_arguments
    # @param [Hash] parameters
    # @param [Hash] metadata
    def initialize(action:, action_arguments:, parameters:, metadata: {})
      @action           = action
      @action_arguments = action_arguments
      @parameters       = parameters
      @metadata         = metadata
    end

    def response_body
      @response_body || http_response.try(:body)
    end

    def process_response
      # Reraise ResponseErrors to include ourselves. Not
      # pretty, but I can't think of anything nicer right now
      begin
        @result = action.process_response(response_body)
      rescue ResponseError => e
        e.request = self
        raise e
      end
    end

    def to_s
      [
        "Apidiesel::Request",
        action.http_method.to_s.upcase,
        url.try(:to_s),
        action.endpoint,
        parameters.collect { |key, value| "#{key}: #{value}"}.join(',')
      ].join(' ')
    end
  end
end
