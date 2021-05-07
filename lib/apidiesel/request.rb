# frozen_string_literal: true

module Apidiesel
  # Wrapper for API requests
  class Request
    # @return [Apidiesel::Endpoint] the endpoint instance which
    #   built this request
    attr_accessor :endpoint
    # @return [Hash] the raw parameters passed by the user into
    #   the endpoint. Also includes parameters which are not included
    #   in `parameters`, because they are marked as `submit: false`
    attr_accessor :endpoint_arguments
    # @return [Hash] the request parameters to be transmitted, processed
    #   and filtered by the `expects {}` block validations
    attr_accessor :parameters
    # @return [URI] the request URI
    attr_accessor :url
    # @return [Object] the response body after all processing by every
    #   involved response handler (eg., a parsed JSON response). Falls back
    #   to the raw response body if no processing took place
    attr_accessor :response_body
    # @return [HTTPI::Request]
    attr_accessor :http_request
    # @return [HTTPI::Response]
    attr_accessor :http_response
    # @return [Hash] additional freeform data attached by request and response
    #   handlers, such as timings
    attr_accessor :metadata
    # @return [Object] the final response result, as processed by the endpoints
    #   `responds_with {}` block
    attr_accessor :result

    # @param endpoint           [Apidiesel::Endpoint] the endpoint instance which
    #   built this request
    # @param endpoint_arguments [Hash] the raw parameters passed by the user into
    #   the endpoint. Also includes parameters which are not included
    #   in `parameters`, because they are marked as `submit: false`
    # @param parameters         [Hash] the request parameters to be transmitted, processed
    #   and filtered by the `expects {}` block validations
    # @param metadata           [Hash] additional freeform data attached by request and response
    #   handlers, such as timings
    # @return [self]
    def initialize(endpoint:, endpoint_arguments:, parameters:, metadata: {})
      @endpoint           = endpoint
      @endpoint_arguments = endpoint_arguments
      @parameters         = parameters
      @metadata           = metadata
    end

    # The response body after all processing by every involved response handler
    # (eg., a parsed JSON response). Falls back to the raw response body if no
    # processing took place
    #
    # @return [Object]
    def response_body
      @response_body || http_response.try(:body)
    end

    # Executes the endpoints `responds_with {}` block to create the final `#result`
    #
    # @raise [Apidiesel::ResponseError]
    # @return [void]
    def process_response
      # Reraise ResponseErrors to include ourselves. Not
      # pretty, but I can't think of anything nicer right now
      begin
        @result = endpoint.process_response(response_body)
      rescue ResponseError => e
        e.request = self
        raise e
      end
    end

    # @return [String]
    def to_s
      [
        "Apidiesel::Request",
        endpoint.config.http_method.to_s.upcase,
        url.try(:to_s),
        parameters.collect { |key, value| "#{key}: #{value}"}.join(',')
      ].join(' ')
    end
  end
end
