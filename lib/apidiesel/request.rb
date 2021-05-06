# frozen_string_literal: true

module Apidiesel

  # Wrapper for API requests
  class Request
    attr_accessor :endpoint, :endpoint_arguments, :parameters, :url, :response_body, :http_request, :http_response, :metadata, :result

    # @param endpoint           [Apidiesel::Endpoint]
    # @param endpoint_arguments [Hash]
    # @param parameters         [Hash]
    # @param metadata           [Hash]
    # @return [self]
    def initialize(endpoint:, endpoint_arguments:, parameters:, metadata: {})
      @endpoint           = endpoint
      @endpoint_arguments = endpoint_arguments
      @parameters         = parameters
      @metadata           = metadata
    end

    def response_body
      @response_body || http_response.try(:body)
    end

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
