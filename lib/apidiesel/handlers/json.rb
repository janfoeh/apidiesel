# frozen_string_literal: true

module Apidiesel
  module Handlers
    class JSON < Handler
      include HttpRequestHelper

      def handle_request(request)
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

        return request if request.http_response.blank?

        expected_content_type =
          request.http_request.headers["Accept"]
        received_content_type =
          request.http_response.headers["Content-Type"]

        unless (expected_content_type == received_content_type) || request.http_response.error?
          # request.response_exception =
          #   ResponseError.new "expected Content-Type #{expected_content_type}, "\
          #                     "received #{received_content_type} instead"
          config.logger.warn "expected Content-Type #{expected_content_type}, "\
                              "received #{received_content_type} instead"
        end

        unless request.http_response.body.blank?
          request.response_body =
            ::JSON.parse(request.http_response.body)
        end

        request
      rescue StandardError => ex
        request.request_exception = ex
        request
      end
    end
  end
end
