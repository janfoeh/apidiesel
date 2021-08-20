# frozen_string_literal: true

module Apidiesel
  module Proxies
    # This proxy is used internally by your `Api` instance to look up
    # endpoint classes and namespaces via `method_missing`.
    #
    # If your endpoint namespace contains further subnamespaces, you
    # can access on of them directly:
    #
    # ```ruby
    # module Endpoints
    #   module Subnamespace
    #     class Endpoint < Apidiesel::Endpoint; end
    #   end
    # end
    #
    # api = MyApi.new
    # api.subnamespace
    # # => Apidiesel::Proxies::EndpointNamespace
    # ```
    class EndpointNamespace
      # @return [Module] the namespace module this proxy represents
      attr_reader :namespace
      # @return [Apidiesel::Api] a reference to the Api base instance
      attr_reader :api

      def initialize(api:, namespace:)
        raise ArgumentError,
              "endpoint namespace missing" unless namespace && namespace.is_a?(Module)

        @api       = api
        @namespace = namespace
      end

      def method_missing(method_name, *args, **kargs, &block)
        const = fetch(method_name)

        if const.nil?
          super
        elsif endpoint?(method_name)
          EndpointActions.new(api: api, endpoint: const)
        elsif sub_namespace?(method_name)
          EndpointNamespace.new(api: api, namespace: const)
        end
      end

      def respond_to_missing?(method_name, *args)
        exists?(method_name)
      end

      def exists?(symbol_name)
        symbol_name =
          symbol_to_const_name(symbol_name)

        namespace.const_defined?(symbol_name, false)
      end

      def fetch(symbol_name)
        return nil unless exists?(symbol_name)

        symbol_name =
          symbol_to_const_name(symbol_name)

        namespace.const_get(symbol_name)
      end

      def endpoint?(symbol_name)
        const =
          fetch(symbol_name)

        const && const <= Apidiesel::Endpoint
      end

      def sub_namespace?(symbol_name)
        !endpoint?(symbol_name)
      end

      def symbol_to_const_name(symbol)
        symbol.to_s
              .camelize
              .to_sym
      end
    end

    # This proxy is used to represent the available actions on an
    # endpoint. This is what is returned when you access an endpoint
    # via your `Api` base instance.
    #
    # ```ruby
    # module Endpoints
    #   class MyEndpoint < Apidiesel::Endpoint; end
    # end
    #
    # api = MyApi.new
    # api.my_endpoint
    # # => Apidiesel::Proxies::EndpointActions
    # ```
    class EndpointActions
      # @return [Module] the endpoint class this proxy represents
      attr_reader :endpoint
      # @return [Apidiesel::Api] a reference to the Api base instance
      attr_reader :api

      def initialize(api:, endpoint:)
        @api       = api
        @endpoint = endpoint
      end

      def method_missing(method_name, *args, **kargs, &block)
        method_name = method_name.to_sym

        # Single-action endpoints respond to their http method
        # (`.get`, `.post` etc)
        if endpoint.actions.none?
          if method_name == endpoint.http_method
            api.execute_request(endpoint, *args, **kargs)
          else
            super
          end

        # Endpoints with multiple defined actions respond to the
        # actions names
        else
          if endpoint.for(method_name)
            api.execute_request(endpoint, *args, action: method_name, **kargs)
          else
            super
          end
        end
      end

      def respond_to_missing?(method_name, *args)
        method_name = method_name.to_sym

        if endpoint.actions.none?
          method_name == endpoint.http_method
        else
          endpoint.for(method_name)
        end
      end
    end
  end
end
