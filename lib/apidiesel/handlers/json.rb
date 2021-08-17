# frozen_string_literal: true

module Apidiesel
  module Handlers
    class JSON < Handler
      include HttpRequestHelper

      def handle_request(exchange)
        config  = exchange.endpoint.config
        body =
          params_as_body?(config) ? ::JSON.dump(exchange.parameters) : nil

        execute_request(exchange: exchange, body: body) do |request|
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
    end
  end
end
