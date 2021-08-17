# frozen_string_literal: true

module Apidiesel
  module Handlers
    module HttpRequestHelper
      protected

      # Executes a HTTP request
      #
      # @param exchange [Apidiesel::Exchange]
      # @param body     [Hash] the payload to be sent as request body
      # @yieldparam httpi_request [Request]
      def execute_request(exchange:, body: nil)
        config           = exchange.endpoint.config
        exchange.request = request = HTTPI::Request.new(exchange.url.try(:to_s))

        if config.parameters_as == :query ||
          (config.parameters_as == :auto && config.http_method == :get)
          request.query = exchange.parameters
        end

        if config.headers.present?
          request.headers =
            request.headers
                        .merge(config.headers)
        end

        request.body =
          if body
            body
          elsif exchange.parameters.any? && params_as_body?(config)
            exchange.parameters
          end

        if config.http_basic_username && config.http_basic_password
          request.auth.basic(config.http_basic_username, config.http_basic_password)
        end

        request.auth.ssl.verify_mode = config.ssl_verify_mode
        request.open_timeout         = config.request_timeout
        request.read_timeout         = config.request_timeout

        # note that we yield the Apidiesel::Request, not the raw HTTPI::Request
        yield exchange.request if block_given?

        config.logger.debug "Sending request: #{request.inspect}"

        exchange.metadata[:started_at] = Time.now

        begin
          exchange.response =
            HTTPI.request(exchange.endpoint.config.http_method, request)

          config.logger.debug "Received response: #{exchange.response.inspect}"
        rescue => ex
          config.logger.error "Request failed: #{ex}"
          exchange.request.exception = ex
        ensure
          exchange.metadata[:finished_at] = Time.now
        end

        exchange
      end

      # Send parameters as query parts?
      #
      # @param config [Config]
      # @return [Boolean]
      def params_as_query?(config)
        return true if config.parameters_as == :query
        return true if config.parameters_as == :auto && config.http_method == :get

        false
      end

      # Send parameters as request body?
      #
      # @param config [Config]
      # @return [Boolean]
      def params_as_body?(config)
        return true if config.parameters_as == :body
        return true if config.parameters_as == :auto && config.http_method != :get

        false
      end
    end
  end
end
