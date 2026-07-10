# frozen_string_literal: true

module Apidiesel
  module Handlers
    class JSON < Handler
      include HttpRequestHelper

      def handle_request(exchange)
        config = exchange.endpoint.config

        if config.form_multipart
          raise ArgumentError, "#{exchange.endpoint.class}: form_multipart is incompatible with Handlers::JSON — use Handlers::Form instead"
        end

        execute_request(exchange: exchange,
                        default_accept: "application/json",
                        default_content_type: "application/json")

      rescue StandardError => ex
        config.logger.error "Request failed: #{ex}"
        exchange.request.exception = ex
      end

      def handle_response(exchange)
        config = exchange.endpoint.config

        if exchange.parseable?
          exchange.response.process { |body| ::JSON.parse(body) }
        else
          config.logger.debug "response is not parseable"
        end
      end

      private

      def format_params_for_body(parameters, _config)
        ::JSON.dump(parameters)
      end
    end
  end
end
