# frozen_string_literal: true

module Apidiesel
  module Handlers
    module ResponseProcessor
      class ResponseHandler
        def run(request)
          request.process_response

          request
        end
      end
    end
  end
end
