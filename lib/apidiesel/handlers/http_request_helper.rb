module Apidiesel
  module Handlers
    module HttpRequestHelper
      protected

      # Executes a HTTP request
      #
      # @param [Apidiesel::Request] request
      # @param [Hash] payload the request body
      # @param [Hash] api_config the configuration data of the Apidiesel::Api
      #               instance, as given to the handlers #run method
      #
      def execute_request(request:, payload:, api_config:)
        http_request      = HTTPI::Request.new(request.url.try(:to_s))
        http_request.body = payload

        if api_config[:http_basic_username] && api_config[:http_basic_password]
          http_request.auth.basic(api_config[:http_basic_username], api_config[:http_basic_password])
        end

        http_request.auth.ssl.verify_mode = api_config[:ssl_verify_mode] || :peer
        http_request.open_timeout         = api_config[:timeout] || 30
        http_request.read_timeout         = api_config[:timeout] || 30

        request.http_request = http_request

        begin
          response = HTTPI.request(request.action.http_method, http_request)
          request.http_response = response
        rescue => e
          raise RequestError.new(e, request)
        end

        if response.error?
          raise RequestError.new("#{request.action.http_method} #{request.url} returned #{response.code}", request)
        end

        request
      end
    end
  end
end