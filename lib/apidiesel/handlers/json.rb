# frozen_string_literal: true

module Apidiesel
  module Handlers
    module JSON
      class RequestHandler
        include HttpRequestHelper

        def run(request)
          config  = request.endpoint.config
          payload = nil

          if config.parameters_as == :body ||
            (config.parameters_as == :auto && config.http_method != :get)

            payload = ::JSON.dump(request.parameters)
          end

          request.metadata[:started_at] = DateTime.now

          execute_request(request: request,
                          payload: payload) do |http_request|
            http_request.headers["Accept"] =
              config.headers["Accept"] || "application/json"
            http_request.headers["Content-Type"] =
              config.content_type || "application/json"

            http_request
          end

          request.metadata[:finished_at] = DateTime.now

          if request.http_response.code == 204
            request.response_body = {}
          else
            request.response_body = ::JSON.parse(request.http_response.body)
          end

          request
        end
      end
    end
  end
end
