# frozen_string_literal: true

module Apidiesel

  # This is the abstract main interface class for the Apidiesel gem. It is meant to be
  # inherited from:
  #
  #   module MyApi
  #     class Api < Apidiesel::Api
  #     end
  #   end
  #
  # Apidiesel expects there to be an `Endpoints` namespace alongside the same scope,
  # in which it can find the individual endpoint definitions for this API:
  #
  #   module MyApi
  #     class Api < Apidiesel::Api
  #     end
  #
  #     module Endpoints
  #       class Endpoint1; end
  #       class Endpoint2; end
  #     end
  #   end
  #
  #   # Registers endpoints Endpoint1 and Endpoint2
  #   MyApi::Api.register_endpoints
  #
  class Api
    class << self
      include Handlers

      def config(key = nil, value = nil)
        @config ||= {}

        if key && value
          @config[key] = value
        else
          @config
        end
      end

      # Combined getter/setter for this endpoints URL
      #
      # Falls back to the Api setting if blank.
      #
      # @param base_url [String]
      def url(base_url = nil)
        if base_url
          config[:url] = URI.parse(base_url)
        else
          config[:url]
        end
      end

      # Combined getter/setter for the HTTP method used
      #
      # Falls back to the Api setting if blank.
      #
      # @param value [String]
      def http_method(value = nil)
        if value
          config[:http_method] = value
        else
          config[:http_method]
        end
      end

      # Combined getter/setter for the HTTP Basic Auth
      #
      # Falls back to the Api setting if blank.
      #
      # @param username [String]
      # @param password [String]
      def http_basic_auth(username = nil, password = nil)
        if username && password
          config[:http_basic_username] = username
          config[:http_basic_password] = password
        else
          return config[:http_basic_username], config[:http_basic_password]
        end
      end

      # Registers the individual API endpoint definitions
      def register_endpoints
        namespace = "#{self.name.deconstantize}::Endpoints".safe_constantize

        namespace.constants.each do |endpoint|
          namespace.const_get(endpoint).register(self)
        end
      end

      def logger(logger = nil)
        if logger
          @logger = logger
        else
          @logger
        end
      end
    end

    # @param kargs [Hash]
    def initialize(**kargs)
      @config = kargs.reverse_merge(self.class.config)
    end

    def logger
      self.class.logger
    end

      protected

    def execute_request(endpoint_klass, *args, **kargs)
      request = endpoint_klass.new(self).build_request(*args, **kargs)

      request_handlers =
        endpoint_klass.request_handlers.any? ? endpoint_klass.request_handlers : self.class.request_handlers

      response_handlers =
        endpoint_klass.response_handlers.any? ? endpoint_klass.response_handlers : self.class.response_handlers

      request_handlers.each do |handler|
        request = handler.run(request, @config)
        break if request.response_body != nil
      end

      unless request.response_body != nil
        raise "All request handlers failed to deliver a response"
      end

      response_handlers.each do |handler|
        request = handler.run(request, @config)
      end

      response_handler_klasses =
        response_handlers.collect { |handler| handler.class.name.split('::')[-2] }

      # Execute the endpoints' `responds_with` block automatically, unless
      # the handler has been included manually in order to control the
      # order in which the handlers are run
      unless response_handler_klasses.include?('ResponseProcessor')
        request.process_response
      end

      request
    rescue => e
      exception_handlers =
        endpoint_klass.exception_handlers.any? ? endpoint_klass.exception_handlers : self.class.exception_handlers

      exception_handlers.each do |handler|
        request = handler.run(e, request, @config)
      end

      raise e
    end

  end
end
