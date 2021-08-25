# frozen_string_literal: true

module Apidiesel
  # `Exchange` wraps a single request and response — you might also call it a
  # transaction. You receive an instance of this when executing an endpoint.
  class Exchange
    # @return [Apidiesel::Endpoint] the endpoint instance which
    #   built this exchange
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
    # @return [Request]
    attr_reader :request
    # @return [Response]
    attr_reader :response
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
      @parameters         = parameters || {}
      @metadata           = metadata
    end

    # Random identifier for tracking and logging purposes
    # @return [String]
    def id
      @id ||= SecureRandom.hex
    end

    def request=(httpi_request)
      @request = Request.new(httpi_request)
    end

    def response=(httpi_response)
      @response = Response.new(httpi_response)
    end

    # Has a request been sent?
    #
    # @return [Boolean]
    def requested?
      request.present?
    end

    # Has a request been sent successfully?
    #
    # @return [Boolean]
    def requested_successfully?
      requested? && request.successful?
    end

    # Has a response been received?
    #
    # @return [Boolean]
    def response_received?
      response.present?
    end

    # Has a 2xx/3xx response been received?
    #
    # @return [Boolean]
    def successful_response_received?
      response_received? && response.successful?
    end

    # Has this exchange been requested and received
    # any response?
    #
    # @return [Boolean]
    def fetched?
      requested_successfully? && response_received?
    end

    # Has this exchange been requested and received
    # a 2xx/3xx response?
    #
    # Ignores potential errors during processing.
    #
    # @return [Boolean]
    def fetched_successfully?
      fetched? && successful_response_received?
    end

    # Has this exchange been requested and received
    # anything back that can be parsed?
    #
    # @return [Boolean]
    def parseable?
      fetched? && response.body.present?
    end

    # Has this exchange been requested and received
    # anything back that can be processed?
    #
    # @return [Boolean]
    def processable?
      fetched? && response.parsed_body.present?
    end

    # Has this exchange been fetched and processed
    # successfully?
    #
    # @return [Boolean]
    def successful?
      fetched_successfully? && exception.blank?
    end

    #
    # @return [Boolean]
    def failed?
      !successful?
    end

    # @return [StandardError, nil]
    def exception
      request_exception || response_exception
    end

    # @return [StandardError, nil]
    def request_exception
      request&.exception
    end

    # @return [StandardError, nil]
    def response_exception
      response&.exception
    end

    # Raise the first error that occurred during the request
    # or response phase
    #
    # @raise [StandardError]
    def raise_any_exception
      raise request_exception if request_exception && config.raise_request_errors
      raise response_exception if response_exception && config.raise_response_errors
    end

    # Executes the endpoints `responds_with {}` block to create the final `#result`
    #
    # @raise [Apidiesel::ResponseError]
    # @return [void]
    def process_response
      begin
        @result = endpoint.process_response(self)
      rescue StandardError => ex
        response.exception = ex
      end
    end

    # @return [Apidiesel::Config]
    def config
      endpoint.config
    end

    def duration
      return unless metadata[:started_at] && metadata[:finished_at]

      metadata[:finished_at] - metadata[:started_at]
    end

    # @return [String]
    def to_s
      [
        "Apidiesel::Exchange",
        endpoint.class.descriptive_name,
        config.http_method.to_s.upcase,
        url.try(:to_s),
        parameters.collect { |key, value| "#{key}: #{value}"}.join(',')
      ].join(' ')
    end

    def inspect
      output = to_s

      if request
        output << <<~EOT

          Exchange successful: #{successful?}

          Request:
            - HEADERS: #{request.headers.inspect}
            - BODY: #{request.body.inspect if request.body}
        EOT
      end

      if duration
        output << "Duration: #{duration}s"
      end

      if response
        output << <<~EOT

          Response:
            - CODE: #{response.code}
            - HEADERS: #{response.headers.inspect}
            - BODY: #{(response.parsed_body || response.body).inspect}
        EOT
      end
    end
  end
end
