# frozen_string_literal: true

module Apidiesel
  module Handlers
    class BearerToken < Handler
      def handle_request(exchange)
        config = exchange.endpoint.config

        unless config.bearer_token.nil?
          if config.present?(:headers, only_self: true)
            config.set(:headers, config.headers.merge("Authorization" => "Bearer #{config.bearer_token}"))
          else
            config.set(:headers, { "Authorization" => "Bearer #{config.bearer_token}" })
          end
        end

        exchange
      end
    end
  end
end
