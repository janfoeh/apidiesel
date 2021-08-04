# frozen_string_literal: true

module Apidiesel
  module Handlers
    module HttpRequestHelper
      protected

      # Executes a HTTP request
      #
      # @param request    [Apidiesel::Request]
      # @param payload    [Hash]  the request body
      #   instance, as given to the handlers #run method
      #
      def execute_request(request:, payload: nil)
        config       = request.endpoint.config
        http_request = HTTPI::Request.new(request.url.try(:to_s))

        if config.parameters_as == :query ||
          (config.parameters_as == :auto && config.http_method == :get)
          http_request.query = request.parameters
        end

        if config.headers.present?
          http_request.headers =
            http_request.headers
                        .merge(config.headers)
        end

        http_request.body =
          if payload
            payload
          elsif request.parameters.any? && config.parameters_as == :body
            request.parameters
          end

        if config.http_basic_username && config.http_basic_password
          http_request.auth.basic(config.http_basic_username, config.http_basic_password)
        end

        http_request.auth.ssl.verify_mode = config.ssl_verify_mode
        http_request.open_timeout         = config.request_timeout
        http_request.read_timeout         = config.request_timeout

        if block_given?
          http_request = yield http_request
        end

        request.http_request = http_request

        config.logger.debug "Sending HTTP request: #{http_request.inspect}"

        begin
          response = HTTPI.request(request.endpoint.config.http_method, http_request)
          request.http_response = response
          config.logger.debug "Received HTTP response: #{response.inspect}"
        rescue => e
          config.logger.error "HTTP request failed: #{e}"
          request.request_exception = e
        end

        request
      end
    end
  end
end
