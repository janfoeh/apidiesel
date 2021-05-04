# frozen_string_literal: true

module Apidiesel
  module Handlers
    module JSON
      class RequestHandler
        include HttpRequestHelper

        def run(request, api_config)
          payload = ::JSON.dump(request.parameters)

          request.metadata[:started_at] = DateTime.now

          execute_request(request: request,
                          payload: payload,
                          api_config: api_config) do |http_request|
            http_request.headers = {"Accept" => "application/json", "Content-Type" => "application/json"}
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
