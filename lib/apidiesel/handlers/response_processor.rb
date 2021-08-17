# frozen_string_literal: true

module Apidiesel
  module Handlers
    class ResponseProcessor < Handler
      def handle_response(request)
        request.process_response if request.request_successful?

        request
      end
    end
  end
end
