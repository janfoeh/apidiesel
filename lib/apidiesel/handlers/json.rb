# frozen_string_literal: true

module Apidiesel
  module Handlers
    class JSON < Handler
      include HttpRequestHelper

      def handle_request(exchange)
        config = exchange.endpoint.config

        execute_request(exchange: exchange) do |request|
          request.headers["Accept"] =
            config.headers["Accept"] || "application/json"

          request.headers["Content-Type"] =
            config.content_type || "application/json"
        end

        if exchange.parseable?
          exchange.response.process { |body| ::JSON.parse(body) }
        else
          config.logger.debug "response is not parseable"
        end

        exchange
      rescue StandardError => ex
        config.logger.error "Request failed: #{ex}"
        exchange.request.exception = ex
        exchange
      end

      private

      def format_params_for_body(parameters)
        ::JSON.dump(parameters)
      end
    end
  end
end
