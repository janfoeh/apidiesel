# frozen_string_literal: true

module Apidiesel
  module Handlers
    class ResponseProcessor < Handler
      def handle_response(request)
        request.process_response

        request
      end
    end
  end
end
