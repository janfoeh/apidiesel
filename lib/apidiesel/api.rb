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
    # @return [Hash{Symbol=>Object}]
    attr_reader :config
    # @return [Apidiesel::Proxies::EndpointNamespace]
    attr_reader :namespace_proxy

    module MockLogger
      class << self
        [:fatal, :error, :warn, :info, :notice].each do |level|
          define_method(level) { |*_args, **_kargs| }
        end
      end
    end

    class << self
      include Handlers

      def config
        @config ||= begin
          default_namespace =
            "#{self.name.deconstantize}::Endpoints".safe_constantize

          Config.new do
            endpoint_namespace      default_namespace
            base_url                nil
            http_method             :get
            http_basic_username     nil
            http_basic_password     nil
            content_type            nil
            headers                 {}
            ssl_verify_mode         :peer
            request_timeout         30
            parameters_as           :auto
            include_nil_parameters  false
            logger                  MockLogger
          end
        end
      end

      %i(endpoint_namespace base_url http_method http_basic_username http_basic_password
         content_type headers ssl_verify_mode timeout parameters_as logger).each do |config_key|
        define_method(config_key) do |value = nil|
          value.present? ? config.set(config_key, value) : config.fetch(config_key)
        end
      end
    end

    # @param kargs [Hash]
    def initialize(**kargs)
      @config = Config.new(kargs, parent: self.class.config)
      @namespace_proxy =
        Proxies::EndpointNamespace.new(api: self, namespace: config.endpoint_namespace)
    end

    def url
      config[:url]
    end

    def http_method
      config[:http_method]
    end

    def http_basic_auth
      config[:http_basic_auth]
    end

    def logger
      self.class.logger
    end

    def method_missing(method_name, *args, **kargs, &block)
      if namespace_proxy.respond_to?(method_name)
        namespace_proxy.send(method_name, *args, **kargs, &block)
      else
        super
      end
    end

    def respond_to_missing?(method_name, *args)
      namespace_proxy.respond_to?(method_name)
    end

    def execute_request(endpoint_klass, *args, action: nil, **kargs)
      request =
        if action
          endpoint_klass.for(action)
                        .new(self).build_request(*args, **kargs)
        else
          endpoint_klass.new(self).build_request(*args, **kargs)
        end

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
