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
    extend Handlers

    # @return [Hash{Symbol=>Object}]
    attr_reader :config
    # @return [Apidiesel::Proxies::EndpointNamespace]
    attr_reader :namespace_proxy

    module MockLogger
      class << self
        [:fatal, :error, :warn, :info, :notice, :debug].each do |level|
          define_method(level) { |*_args, **_kargs| }
        end

        def tagged(*_args)
          yield
        end
      end
    end

    class << self
      def config
        @config ||= begin
          default_endpoint_namespace =
            "#{self.name.deconstantize}::Endpoints".safe_constantize

          Config.new(label: name) do
            request_handlers        value: -> { [] }
            response_handlers       value: -> { [] }
            exception_handlers      value: -> { [] }
            endpoint_namespace      default_endpoint_namespace
            base_url                nil
            http_method             :get
            http_basic_username     nil
            http_basic_password     nil
            content_type            nil
            headers                 value: -> { {} }
            ssl_verify_mode         :peer
            request_timeout         30
            parameters_as           :auto
            include_nil_parameters  false
            raise_request_errors    false
            raise_response_errors   false
            logger                  MockLogger
          end
        end
      end

      %i(endpoint_namespace base_url http_method http_basic_username
          http_basic_password content_type headers ssl_verify_mode
          timeout parameters_as logger).each do |config_key|
        define_method(config_key) do |value = nil|
          value.present? ? config.set(config_key, value) : config.fetch(config_key)
        end
      end
    end

    # @param kargs [Hash]
    def initialize(**kargs)
      @config =
        Config.new(kargs, parent: self.class.config.dup, label: "Instance of #{self.class.name}")
      @namespace_proxy =
        Proxies::EndpointNamespace.new(api: self, namespace: config.endpoint_namespace)
    end

    def logger
      config.logger
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
      exchange =
        if action
          endpoint_klass.for(action)
                        .new(self).build_exchange(*args, **kargs)
        else
          endpoint_klass.new(self).build_exchange(*args, **kargs)
        end

      logger.tagged(endpoint_klass.name, exchange.id) do
        config.request_handlers.each do |handler|
          logger.debug "executing request handler #{handler.class.name}"
          exchange = handler.handle_request(exchange)
          break if exchange.requested?
        end

        exchange.raise_any_exception

        unless exchange.requested?
          raise "All request handlers failed to send a request"
        end

        config.response_handlers.each do |handler|
          logger.debug "executing response handler #{handler.class.name}"
          exchange = handler.handle_response(exchange)
        end

        # Execute the endpoints' `responds_with` block automatically, unless
        # the handler has been included manually in order to control the
        # order in which the handlers are run
        unless config.response_handlers
                      .any? { |handler| handler.is_a?(ResponseProcessor) }
          exchange = Handlers::ResponseProcessor.new.handle_response(exchange)
        end

        exchange.raise_any_exception

        logger.debug "parsed response result: #{exchange.result.inspect}"
      end

      exchange
    rescue => ex
      if config.exception_handlers.any?
        config.exception_handlers.each do |handler|
          exchange = handler.handle_exception(ex, exchange)
        end
      else
        raise ex
      end
    end

  end
end
