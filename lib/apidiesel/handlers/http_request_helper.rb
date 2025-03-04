# frozen_string_literal: true

module Apidiesel
  module Handlers
    module HttpRequestHelper
      private

      # Executes a HTTP request
      #
      # @param exchange [Apidiesel::Exchange]
      # @param body     [Hash] the payload to be sent as request body
      # @yieldparam httpi_request [Request]
      def execute_request(exchange:, body: nil, default_accept: nil, default_content_type: nil)
        config     = exchange.endpoint.config
        connection = Faraday.new(ssl: { verify_mode: config.ssl_verify_mode })

        if config.form_multipart
          connection.request :multipart
        end

        if config.http_basic_username && config.http_basic_password
          connection.request(:authorization, :basic, config.http_basic_username, config.http_basic_password)
        end

        exchange.response =
          connection.run_request(exchange.endpoint.config.http_method,
                                  exchange.url.try(:to_s),
                                  nil,
                                  config.headers) do |request|
            request.options.open_timeout = config.request_timeout
            request.options.read_timeout = config.request_timeout

            if accept_header(default_accept, config)
              request.headers["Accept"] = accept_header(default_accept, config)
            else
              request.headers.delete("Accept")
            end

            if content_type(default_content_type, config)
              request.headers["Content-Type"] = content_type(default_content_type, config)
            else
              request.headers.delete("Content-Type")
            end

            request.params.update(format_params_for_query(exchange.parameters, config)) if params_as_query?(config)
            request.body = format_params_for_body(body || exchange.parameters, config) if params_as_body?(config)

            yield request if block_given?

            config.logger.debug "Sending request: #{request.inspect}"

            exchange.request = request

            exchange.metadata[:started_at] = Time.now
          end

        config.logger.debug "Received response: #{exchange.response.inspect}"

      rescue => ex
        config.logger.error "Request failed: #{ex}"

        # This might happen if such a low-level exception occurs that Faraday
        # does not produce a request
        if exchange.request.nil?
          # Looks weird, I know, but we are initialising an empty
          # `Apidiesel::Request` wrapper
          exchange.request = nil
        end

        exchange.request.exception = ex

      ensure
        exchange.metadata[:finished_at] = Time.now
      end

      def format_params_for_query(params, _config)
        params
      end

      def format_params_for_body(params, _config)
        params
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

      def accept_header(default, config)
        case config.search_hash_key(:headers, "Accept")
        when FalseClass
          nil
        when String
          config.search_hash_key(:headers, "Accept")
        else
          default
        end
      end

      def content_type(default, config)
        case config.content_type
        when FalseClass
          nil
        when String
          config.content_type
        else
          default
        end
      end
    end
  end
end
