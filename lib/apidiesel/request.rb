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

    def url
      @url ||=
        case action.url
        when Proc
          action.url.call(action.base_url, self)
        when URI
          action.url
        end
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
        raise ResponseError.new(e.message, self)
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
