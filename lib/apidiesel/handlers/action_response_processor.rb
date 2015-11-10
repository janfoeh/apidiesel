module Apidiesel
  module Handlers
    module ActionResponseProcessor
      class ResponseHandler
        def run(request, _)
          request.process_response

          request
        end
      end
    end
  end
end