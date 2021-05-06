# frozen_string_literal: true

module Apidiesel
  module Handlers
    module HttpRequestHelper
      protected

      # Executes a HTTP request
      #
      # @param request    [Apidiesel::Request]
      # @param payload    [Hash]  the request body
      # @param api_config [Hash]  the configuration data of the Apidiesel::Api
      #   instance, as given to the handlers #run method
      #
      def execute_request(request:, api_config:, payload: nil)
        http_request = HTTPI::Request.new(request.url.try(:to_s))

        if api_config.parameters_as == :query ||
          (api_config.parameters_as == :auto && api_config.http_method == :get)
          http_request.query = request.parameters
        end

        http_request.body =
          if payload
            payload
          elsif request.parameters.any? && api_config.parameters_as == :body
            request.parameters
          end

        if api_config.http_basic_username && api_config.http_basic_password
          http_request.auth.basic(api_config.http_basic_username, api_config.http_basic_password)
        end

        http_request.auth.ssl.verify_mode = api_config.ssl_verify_mode
        http_request.open_timeout         = api_config.request_timeout
        http_request.read_timeout         = api_config.request_timeout

        if block_given?
          http_request = yield http_request
        end

        request.http_request = http_request

        begin
          response = HTTPI.request(api_config.http_method, http_request)
          request.http_response = response
        rescue => e
          raise RequestError.new(e, request)
        end

        if response.error?
          raise RequestError.new("#{api_config.http_method} #{request.url} returned #{response.code}", request)
        end

        request
      end
    end
  end
end
