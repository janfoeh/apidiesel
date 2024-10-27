# frozen_string_literal: true

module Apidiesel
  module Handlers
    class Form < Handler
      include HttpRequestHelper

      def handle_request(exchange)
        config = exchange.endpoint.config

        execute_request(exchange: exchange,
                        default_accept: "text/html",
                        default_content_type: "application/x-www-form-urlencoded") do |request|
          if config.form_multipart
            request.headers["Content-Type"] = "multipart/form-data"
          end
        end

      rescue StandardError => ex
        config.logger.error "Request failed: #{ex}"
        exchange.request.exception = ex
      end

      def handle_response(exchange)
        config = exchange.endpoint.config

        if exchange.parseable?
          exchange.response.process { |body| body }
        else
          config.logger.debug "response is not parseable"
        end
      end

      private

      def format_params_for_body(parameters, config)
        if config.form_multipart
          parameters
        else
          URI.encode_www_form(parameters)
        end
      end
    end
  end
end
