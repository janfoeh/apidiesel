# frozen_string_literal: true

module Apidiesel
  module Handlers
    class ResponseProcessor < Handler
      def handle_response(exchange)
        exchange.process_response if exchange.processable?
      end
    end
  end
end
