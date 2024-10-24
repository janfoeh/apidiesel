# frozen_string_literal: true

module Apidiesel
  module Handlers
    class JSON < Handler
      include HttpRequestHelper

      def handle_request(exchange)
        config = exchange.endpoint.config

        execute_request(exchange: exchange) do |request|
          accept_header =
            case config.search_hash_key(:headers, "Accept")
            when NilClass
              "application/json"
            when String
              config.search_hash_key(:headers, "Accept")
            else
              nil
            end

          if accept_header
            request.headers["Accept"] = accept_header
          else
            request.headers.delete("Accept")
          end

          content_type =
            case config.content_type
            when NilClass
              "application/json"
            when String
              content_type
            else
              nil
            end

          request.headers["Content-Type"] = content_type if content_type
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
